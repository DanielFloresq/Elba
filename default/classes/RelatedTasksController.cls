/**
 * @description       : Controller for managing related tasks with creation and subject suggestion features
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 30-04-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class RelatedTasksController {
    /**
     * @description Retrieves related tasks for a given record, including parent-child task hierarchies
     * @param recordId The ID of the record (Task or other SObject) to fetch related tasks for
     * @return List of related Task records ordered by ActivityDate and CreatedDate descending
     */
    @AuraEnabled(cacheable=true)
    public static List<Task> getRelatedTasks(Id recordId) {
        if (recordId == null) {
            return new List<Task>();
        }

        // Check if recordId is a Task
        String objectType = recordId.getSObjectType().getDescribe().getName();
        if (objectType == 'Task') {
            // If it's a task, get the task and its related tasks
            List<Task> currentTask = [
                SELECT Id, Subject, Status, ActivityDate, CreatedDate, RecurrenceActivityId, LookUpTask__c, Owner.Name, WhatId, WhoId, What.Name, Who.Name, CreatedById, CreatedBy.SmallPhotoUrl, Theme__c, SubTheme__c, ReminderDateTime
                FROM Task
                WHERE Id = :recordId
                AND IsDeleted = false
            ];
            if (currentTask.isEmpty()) {
                return new List<Task>();
            }
            Task t = currentTask[0];
            Set<Id> parentIds = new Set<Id>();
            if (t.LookUpTask__c != null) {
                // It's a child, get the parent
                parentIds.add(t.LookUpTask__c);
            } else {
                // It's a parent, get itself
                parentIds.add(t.Id);
            }

            List<Task> relatedTasks = [
                SELECT Id, Subject, Status, ActivityDate, CreatedDate, RecurrenceActivityId, LookUpTask__c, Owner.Name, WhatId, WhoId, What.Name, Who.Name, CreatedById, CreatedBy.SmallPhotoUrl, Theme__c, SubTheme__c, ReminderDateTime
                FROM Task
                WHERE (Id IN :parentIds OR LookUpTask__c IN :parentIds)
                AND IsDeleted = false
                ORDER BY ActivityDate DESC, CreatedDate DESC
            ];
            return relatedTasks;
        } else {
            // Build the set of WhatIds to search: always includes the recordId itself
            Set<Id> whatIds = new Set<Id>{ recordId };

            // If the record is an Order, include its related Services
            if (objectType == 'Order') {
                for (Service__c s : [SELECT Id FROM Service__c WHERE Order__c = :recordId]) {
                    whatIds.add(s.Id);
                }
            }

            // If the record is a Case, also include related Orders (via Order.CaseNumber__c) and their Services
            if (objectType == 'Case') {
                Set<Id> orderIds = new Set<Id>();
                for (Order o : [SELECT Id FROM Order WHERE CaseNumber__c = :recordId]) {
                    orderIds.add(o.Id);
                    whatIds.add(o.Id);
                }
                if (!orderIds.isEmpty()) {
                    for (Service__c s : [SELECT Id FROM Service__c WHERE Order__c IN :orderIds]) {
                        whatIds.add(s.Id);
                    }
                }
            }

            List<Task> parentTasks = [
                SELECT Id, Subject, Status, ActivityDate, RecurrenceActivityId, LookUpTask__c, Owner.Name, WhatId, WhoId, What.Name, Who.Name, CreatedDate, CreatedById, CreatedBy.SmallPhotoUrl, Theme__c, SubTheme__c, ReminderDateTime
                FROM Task
                WHERE (WhatId IN :whatIds OR WhoId IN :whatIds)
                AND LookUpTask__c = null
                AND IsDeleted = false
                ORDER BY ActivityDate DESC, CreatedDate DESC
            ];

            Set<Id> parentIds = new Set<Id>();
            for (Task t : parentTasks) {
                parentIds.add(t.Id);
            }

            List<Task> childTasks = parentIds.isEmpty()
                ? new List<Task>()
                : [
                    SELECT Id, Subject, Status, ActivityDate, CreatedDate, RecurrenceActivityId, LookUpTask__c, Owner.Name, WhatId, WhoId, What.Name, Who.Name, CreatedById, CreatedBy.SmallPhotoUrl, Theme__c, SubTheme__c, ReminderDateTime
                    FROM Task
                    WHERE LookUpTask__c IN :parentIds
                    AND IsDeleted = false
                    ORDER BY ActivityDate DESC, CreatedDate DESC
                ];

            List<Task> results = new List<Task>();
            results.addAll(parentTasks);
            results.addAll(childTasks);
            return results;
        }
    }

    /**
     * @description Creates a parent task after validating the subject against TaskSubjectTree__mdt and checking for duplicates
     * @param subject The subject for the new task (must exist in TaskSubjectTree__mdt)
     * @param activityDate The due date for the task
     * @param ownerId The owner ID for the task
     * @param whoId The Who (Contact/Lead) ID to relate the task to
     * @param whatId The What (Account/Case/etc.) ID to relate the task to
     * @return Id of the newly created Task
     */
    @AuraEnabled
    public static Id createParentTask(String subject, Date activityDate, Id ownerId, Id whoId, Id whatId) {
        if (String.isBlank(subject)) {
            throw new AuraHandledException('El campo Asunto es obligatorio');
        }

        // Validate that subject exists in TaskSubjectTree__mdt as a ParentSubject__c
        Boolean validSubject = false;
        try {
            Integer cnt = [SELECT count() FROM TaskSubjectTree__mdt WHERE ParentSubject__c = :subject];
            validSubject = (cnt > 0);
        } catch (Exception ignore) {
            validSubject = false;
        }
        if (!validSubject) {
            throw new AuraHandledException('Asunto inválido. Por favor seleccione un asunto de la lista.');
        }

        // If related to a record, ensure there is no non-completed task with the same subject
        if (whatId != null) {
            Set<String> completedTerms = new Set<String>{'completed','completado','concluido','concluida','finalizado','hecho','done'};
            List<Task> existing = [SELECT Id, Status FROM Task WHERE (WhatId = :whatId OR WhoId = :whatId) AND Subject = :subject AND IsDeleted = false];
            for (Task e : existing) {
                String st = (e.Status == null) ? '' : e.Status.toLowerCase();
                if (!completedTerms.contains(st)) {
                    throw new AuraHandledException('Ya existe una tarea no concluida con ese asunto relacionada a este registro.');
                }
            }
        }

        Task t = new Task(Subject = subject);
        if (activityDate != null) t.ActivityDate = activityDate;
        if (ownerId != null) t.OwnerId = ownerId;
        if (whoId != null) t.WhoId = whoId;
        if (whatId != null) t.WhatId = whatId;
        // Ensure parent flag is null
        t.LookUpTask__c = null;
        try {
            insert t;
            return t.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error al crear la tarea: ' + e.getMessage());
        }
    }

    public class SubjectSuggestion {
        @AuraEnabled public String child;
        @AuraEnabled public String parent;
        @AuraEnabled public String label;
        @AuraEnabled public String masterLabel;
        public SubjectSuggestion(String child, String parent, String masterLabel) {
            this.child = child;
            this.parent = parent;
            this.masterLabel = masterLabel;
            this.label = (parent != null ? parent + ' — ' : '') + child;
        }
    }

    /**
     * @description Returns subject suggestions from TaskSubjectTree__mdt filtered by query string and excluding non-completed existing tasks
     * @param q The search query string to match against parent subjects
     * @param recordId The record ID used to filter out subjects with existing non-completed tasks
     * @return List of SubjectSuggestion matching the query
     */
    @AuraEnabled(cacheable=true)
    public static List<SubjectSuggestion> getSubjectSuggestions(String q, Id recordId) {
        List<SubjectSuggestion> result = new List<SubjectSuggestion>();
        if (String.isBlank(q)) return result;
        String likeQ = '%' + String.escapeSingleQuotes(q) + '%';
        // Query custom metadata TaskSubjectTree__mdt matching ParentSubject__c (search by parent)
        List<TaskSubjectTree__mdt> mdts = [
            SELECT MasterLabel, ChildSubject__c, ParentSubject__c
            FROM TaskSubjectTree__mdt
            WHERE ParentSubject__c != null AND ParentSubject__c LIKE :likeQ
            LIMIT 200
        ];

        if (mdts.isEmpty()) return result;

        // Build set of subjects already related to the recordId BUT only count those that are NOT completed
        Set<String> existing = new Set<String>();
        if (recordId != null) {
            List<Task> relatedTasks = [
                SELECT Subject, Status
                FROM Task
                WHERE (WhatId = :recordId OR WhoId = :recordId)
                AND Subject != null
            ];
            Set<String> completedTerms = new Set<String>{'completed','completado','concluido','concluída','concluida','feito','done'};
            for (Task t : relatedTasks) {
                String st = (t.Status == null) ? '' : t.Status.toLowerCase();
                if (!completedTerms.contains(st)) {
                    existing.add(t.Subject);
                }
            }
        }

        // Map mdts into suggestions, exclude those already present (non-completed)
        // Use parent+child as uniqueness to allow same child under different parents
        Set<String> seen = new Set<String>();
        for (TaskSubjectTree__mdt m : mdts) {
            if (m.ChildSubject__c == null) continue;
            if (m.ParentSubject__c != null && existing.contains(m.ParentSubject__c)) continue;
            String parentKey = m.ParentSubject__c == null ? '' : m.ParentSubject__c;
            String seenKey = parentKey + '|' + m.ChildSubject__c;
            if (seen.contains(seenKey)) continue;
            seen.add(seenKey);
            result.add(new SubjectSuggestion(m.ChildSubject__c, m.ParentSubject__c, m.MasterLabel));
        }

        return result;
    }

    /**
     * @description Retrieves record information including label, owner ID, and owner name for a given record
     * @param recordId The ID of the record to retrieve info for (supports Case, Account, Order, Contact)
     * @return Map with keys objectType, label, ownerId, and ownerLabel
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getRecordInfo(Id recordId) {
        Map<String, String> res = new Map<String, String>();
        if (recordId == null) {
            return res;
        }
        String objectType = recordId.getSObjectType().getDescribe().getName();
        res.put('objectType', objectType);
        try {
            if (objectType == 'Task') {
                Task tk = [SELECT Id, Subject, Status, Theme__c, SubTheme__c, OwnerId, Owner.Name FROM Task WHERE Id = :recordId LIMIT 1];
                res.put('label', tk.Subject != null ? tk.Subject : '');
                res.put('ownerId', String.valueOf(tk.OwnerId));
                res.put('ownerLabel', tk.Owner != null ? tk.Owner.Name : '');
                res.put('theme', tk.Theme__c != null ? tk.Theme__c : '');
                res.put('subtheme', tk.SubTheme__c != null ? tk.SubTheme__c : '');
            } else if (objectType == 'Case') {
                Case c = [SELECT Id, CaseNumber, Subject, OwnerId, Owner.Name FROM Case WHERE Id = :recordId LIMIT 1];
                String label = (c.CaseNumber != null ? c.CaseNumber : '') + (c.Subject != null ? ' - ' + c.Subject : '');
                res.put('label', label);
                res.put('ownerId', String.valueOf(c.OwnerId));
                res.put('ownerLabel', c.Owner != null ? c.Owner.Name : '');
            } else if (objectType == 'Account') {
                Account a = [SELECT Id, Name, OwnerId, Owner.Name FROM Account WHERE Id = :recordId LIMIT 1];
                res.put('label', a.Name);
                res.put('ownerId', String.valueOf(a.OwnerId));
                res.put('ownerLabel', a.Owner != null ? a.Owner.Name : '');
            } else if (objectType == 'Order') {
                Order o = [SELECT Id, OrderNumber, Account.Name, OwnerId, Owner.Name FROM Order WHERE Id = :recordId LIMIT 1];
                String label = (o.OrderNumber != null ? o.OrderNumber : '');
                if (o.Account != null && o.Account.Name != null) {
                    label += (String.isBlank(label) ? '' : ' - ') + o.Account.Name;
                }
                res.put('label', label);
                res.put('ownerId', String.valueOf(o.OwnerId));
                res.put('ownerLabel', o.Owner != null ? o.Owner.Name : '');
            } else if (objectType == 'Contact') {
                Contact ctc = [SELECT Id, Name, OwnerId, Owner.Name FROM Contact WHERE Id = :recordId LIMIT 1];
                res.put('label', ctc.Name);
                res.put('ownerId', String.valueOf(ctc.OwnerId));
                res.put('ownerLabel', ctc.Owner != null ? ctc.Owner.Name : '');
            } else {
                res.put('label', String.valueOf(recordId));
            }
        } catch (Exception e) {
            res.put('label', String.valueOf(recordId));
        }
        return res;
    }

    /**
     * @description Retrieves all TaskSubjectTree__mdt custom metadata records for task creation configuration
     * @return List of TaskSubjectTree__mdt records with ChildSubject__c and ParentSubject__c fields
     */
    @AuraEnabled(cacheable=true)
    public static List<TaskSubjectTree__mdt> getCreateTaskMetadata(){
        List<TaskSubjectTree__mdt> result = [SELECT ChildSubject__c, ParentSubject__c FROM TaskSubjectTree__mdt];
        return result;
    }

    public class ServiceInfo {
        @AuraEnabled public String serviceId;
        @AuraEnabled public String serviceName;
        @AuraEnabled public String serviceType;
    }

    /**
     * @description Returns service info (id, name, resolved type label) for services related to an Order or a Case's related Orders
     * @param recordId The Order or Case record ID
     * @return List of ServiceInfo
     */
    @AuraEnabled(cacheable=true)
    public static List<ServiceInfo> getRelatedServicesInfo(Id recordId) {
        if (recordId == null) return new List<ServiceInfo>();
        String objectType = recordId.getSObjectType().getDescribe().getName();
        Set<Id> orderIds = new Set<Id>();
        if (objectType == 'Order') {
            orderIds.add(recordId);
        } else if (objectType == 'Case') {
            for (Order o : [SELECT Id FROM Order WHERE CaseNumber__c = :recordId]) {
                orderIds.add(o.Id);
            }
        }
        List<ServiceInfo> result = new List<ServiceInfo>();
        if (orderIds.isEmpty()) return result;
        Map<String, String> typeLabels = new Map<String, String>();
        for (Schema.PicklistEntry pe : Schema.SObjectType.Service__c.fields.Type__c.getPicklistValues()) {
            typeLabels.put(pe.getValue(), pe.getLabel());
        }
        for (Service__c s : [SELECT Id, Name, Type__c FROM Service__c WHERE Order__c IN :orderIds]) {
            ServiceInfo si = new ServiceInfo();
            si.serviceId = String.valueOf(s.Id);
            si.serviceName = s.Name;
            String rawType = s.Type__c;
            si.serviceType = rawType != null ? (typeLabels.containsKey(rawType) ? typeLabels.get(rawType) : rawType) : '';
            result.add(si);
        }
        return result;
    }

    public class OrderInfo {
        @AuraEnabled public String orderId;
        @AuraEnabled public String orderNumber;
        @AuraEnabled public String guildLabel;
    }

    /**
     * @description Returns order info (id, number, resolved guild label) for orders related to an Order or Case record
     * @param recordId The Order or Case record ID
     * @return List of OrderInfo
     */
    @AuraEnabled(cacheable=true)
    public static List<OrderInfo> getRelatedOrdersInfo(Id recordId) {
        if (recordId == null) return new List<OrderInfo>();
        String objectType = recordId.getSObjectType().getDescribe().getName();
        Map<String, String> guildLabels = new Map<String, String>();
        for (Schema.PicklistEntry pe : Schema.SObjectType.Order.fields.Guild__c.getPicklistValues()) {
            guildLabels.put(pe.getValue(), pe.getLabel());
        }
        List<Order> orders = new List<Order>();
        if (objectType == 'Order') {
            orders = [SELECT Id, OrderNumber, Guild__c FROM Order WHERE Id = :recordId LIMIT 1];
        } else if (objectType == 'Case') {
            orders = [SELECT Id, OrderNumber, Guild__c FROM Order WHERE CaseNumber__c = :recordId];
        }
        List<OrderInfo> result = new List<OrderInfo>();
        for (Order o : orders) {
            OrderInfo oi = new OrderInfo();
            oi.orderId = String.valueOf(o.Id);
            oi.orderNumber = o.OrderNumber;
            if (o.Guild__c != null) {
                List<String> resolved = new List<String>();
                for (String part : o.Guild__c.split(';')) {
                    String trimmed = part.trim();
                    resolved.add(guildLabels.containsKey(trimmed) ? guildLabels.get(trimmed) : trimmed);
                }
                oi.guildLabel = String.join(resolved, ', ');
            } else {
                oi.guildLabel = '';
            }
            result.add(oi);
        }
        return result;
    }
}