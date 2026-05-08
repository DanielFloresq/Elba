/**
 * @description       : Controller for the case timeline component providing activity, history and record data
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 29-04-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class CaseTimelineController {
    public static Filter filters;
    public static List<String> bookMarked;
    public static Boolean onlyBookMarked = false;
    public static Integer activityIndex = 0;
    public static Integer fieldIndex= 0;

    // icons do layout
    public static Map<String,String> iconNames = new Map<String,String>{
        'CaseHistory' => 'standard:case_change_status',
        'OrderHistory' => 'standard:orders',
        'Service__c' => 'standard:case_change_status',
        'Comments__c' => 'custom:custom62',
        'Event' => 'standard:event',
        'Task' => 'standard:task',
        'EmailMessage' => 'standard:email',
        'ProcessInstanceHistory' => 'standard:approval',
        'Order' => 'standard:orders',
        'Stakeholders__c' => 'standard:custom',
        'Service__History' => 'standard:custom',
        'Incident' => 'standard:case'
    };

    public static Map<String,User> users = new Map<String,User>();
    // public static Map<String,StakeholderContacts__c> stakeholderContactsById = new Map<String,StakeholderContacts__c>();

    /**
     * @description Retrieves all timeline activity items for a given Case filtered by object type and date range
     * @param caseId ID of the Case record
     * @param filter Filter object containing selected object types, start date and end date
     * @return List of Item objects representing timeline entries sorted by date
     */
    @AuraEnabled
    public static List<Item> getActivities(String caseId, Filter filter){
        try {
            filters = filter;
            System.debug('Filters: ' + filters);
            System.debug('selectedObjets: ' + (filters != null ? filters.selectedObjets : null));
            List<Item> allItems = new List<Item>();
            getUsers();
            getBookMarked(caseId);

            if(filters.selectedObjets.contains('Favorites') && filters.selectedObjets.size() == 1){
                onlyBookMarked = true;
            }
            if(filters.selectedObjets.contains('CaseHistory') || onlyBookMarked){
                allItems.addAll(getCaseStatusHistory(caseId));
            }
            if(filters.selectedObjets.contains('OrderHistory') || onlyBookMarked){
                allItems.addAll(getOrderHistory(caseId));
            }
            if(filters.selectedObjets.contains('Service__History') || onlyBookMarked){
                allItems.addAll(getStakeholdersContactHistory(caseId));
            }
            if(filters.selectedObjets.contains('Service__c') || onlyBookMarked){
                System.debug('Calling getStakeholdersContacts for Service__c');
                allItems.addAll(getStakeholdersContacts(caseId));
            }
            if(filters.selectedObjets.contains('Incident') || onlyBookMarked){
                allItems.addAll(getIncidencias(caseId));
            }
            if(filters.selectedObjets.contains('Comments__c') || onlyBookMarked){
                allItems.addAll(getCommentsWithoutHitos(caseId));
            }
            if(filters.selectedObjets.contains('Hitos') || onlyBookMarked){
                allItems.addAll(getCommentsWithHitos(caseId));
            }
            if(filters.selectedObjets.contains('Event') || onlyBookMarked){
                allItems.addAll(getEvents(caseId));
            }
            if(filters.selectedObjets.contains('Task') || onlyBookMarked){
                allItems.addAll(getTasks(caseId));
            }
            if(filters.selectedObjets.contains('EmailMessage') || onlyBookMarked){
                allItems.addAll(getEmails(caseId));
            }
            if(filters.selectedObjets.contains('ProcessInstanceHistory') || onlyBookMarked){
                allItems.addAll(getApprovals(caseId));
            }
            if(filters.selectedObjets.contains('Order') || onlyBookMarked){
                allItems.addAll(getServicos(caseId));
            }
            if(filters.selectedObjets.contains('Stakeholders__c') || onlyBookMarked){
                allItems.addAll(getStakeholders(caseId));
            }
            allItems.sort();
            return allItems;
        } catch (Exception e) {
            throw new AuraHandledException(e.getStackTraceString());
        }
    }

    /**
     * @description Retrieves Case status history records for the given Case within the configured date range
     * @param caseId ID of the Case record
     * @return List of Item objects representing Case status changes
     */
    public static List<Item> getCaseStatusHistory(String caseId){
        if (!Schema.sObjectType.CaseHistory.isAccessible()) {
            //NÃO VALIDA ACESSO ESPECIFICO AOS CAMPOS
            throw new AuraHandledException('Sem acesso ao objeto CaseHistory');
        }
        List<Item> allItems = new List<Item>();
        if (!onlyBookMarked) {
            for (CaseHistory ch : [SELECT Id, CreatedDate, CreatedById, Field, DataType, OldValue, NewValue /*Case.DataDoSinistro__c*/
            FROM CaseHistory
            WHERE CaseId =:caseId
            AND (Field = 'Status' OR Field = 'created')
            AND DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate) AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            ORDER BY CreatedDate ASC]) {
                allItems.add(new Item('CaseHistory', ch, ch.CreatedDate,iconNames.get('CaseHistory'), false, false));
            }
        }
        else{

            for (CaseHistory ch : [SELECT Id, CreatedDate, CreatedById, Field, DataType, OldValue, NewValue /*Case.DataDoSinistro__c*/
            FROM CaseHistory
            WHERE CaseId =:caseId AND (Field = 'Status' OR Field = 'created')
            AND DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate)
            AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            AND Id in: bookMarked
            ORDER BY CreatedDate ASC]) {
                allItems.add(new Item('CaseHistory', ch, ch.CreatedDate,iconNames.get('CaseHistory'), false, false));
            }
        }
        return allItems;
    }



    /**
     * @description Retrieves Order field history records for orders related to the given Case
     * @param caseId ID of the Case record
     * @return List of Item objects representing Order field changes
     */
    public static List<Item> getOrderHistory(String caseId){
        if (!Schema.sObjectType.OrderHistory.isAccessible()) {
            //NÃO VALIDA ACESSO ESPECIFICO AOS CAMPOS
            throw new AuraHandledException('Sem acesso ao objeto OrderHistory');
        }
        List<Item> allItems = new List<Item>();
        if (!onlyBookMarked) {
            for (OrderHistory ch : [SELECT Id, CreatedDate, CreatedById, Field, DataType, OldValue, NewValue, Order.OrderNumber, Order.Guild__c
            FROM OrderHistory
            WHERE Order.CaseNumber__c =:caseId
            AND (Field !=  'created' )
            AND DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate) AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            ORDER BY CreatedDate ASC]) {
                if (ch.OldValue == null || ch.NewValue == null) {
                    continue;

                }
                allItems.add(new Item('OrderHistory', ch, ch.CreatedDate,iconNames.get('OrderHistory'), false, false));
            }
        }
        else{

            for (OrderHistory ch : [SELECT Id, CreatedDate, CreatedById, Field, DataType, OldValue, NewValue, Order.OrderNumber, Order.Guild__c
            FROM OrderHistory
            WHERE Order.CaseNumber__c =:caseId
            AND (Field !=  'created' )
            AND DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate)
            AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            AND Id in: bookMarked
            ORDER BY CreatedDate ASC]) {
                allItems.add(new Item('OrderHistory', ch, ch.CreatedDate,iconNames.get('OrderHistory'), false, false));
            }
        }



        return allItems;
    }
    /**
     * @description Retrieves Service__c field history records for services linked to orders of the given Case
     * @param caseId ID of the Case record
     * @return List of Item objects representing Service field changes
     */
    public static List<Item> getStakeholdersContactHistory(String caseId){
        if (!Schema.sObjectType.Service__History.isAccessible()) {
            //NÃO VALIDA ACESSO ESPECIFICO AOS CAMPOS
            throw new AuraHandledException('Sem acesso ao objeto Service__History ');
        }

        List<String> orderList = new List<String>();
        for (Order ord : [SELECT Id FROM Order WHERE CaseNumber__c = :caseId]) {
            orderList.add(ord.Id);
        }
        List<String> serviceList = new List<String>();
        for (Service__c service : [SELECT Id FROM Service__c WHERE Order__c IN :orderList]) {
            serviceList.add(service.Id);
        }

        List<Item> allItems = new List<Item>();
        if (!onlyBookMarked) {
            for (Service__History ch : [SELECT Id, CreatedDate, CreatedById, Field, DataType, OldValue, NewValue, ParentId
            FROM Service__History
            WHERE ParentId IN :serviceList
            AND (Field !=  'created' )
            AND DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate) AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            ORDER BY CreatedDate ASC]) {
                if (ch.OldValue == null || ch.NewValue == null) {
                    continue;
                }
                allItems.add(new Item('Service__History', ch, ch.CreatedDate,iconNames.get('Service__History'), false, false));
            }
        }
        else{
            for (Service__History ch : [SELECT Id, CreatedDate, CreatedById, Field, DataType, OldValue, NewValue
            FROM Service__History
            WHERE ParentId IN :serviceList
            AND (Field !=  'created' )
            AND DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate) AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate) AND Id in: bookMarked
            ORDER BY CreatedDate ASC]) {
                if (ch.OldValue == null || ch.NewValue == null) {
                    continue;
                }
                allItems.add(new Item('Service__History', ch, ch.CreatedDate,iconNames.get('Service__History'), false, false));
            }
        }

        return allItems;
    }

    /**
     * @description Retrieves Service__c records linked to orders of the given Case
     * @param caseId ID of the Case record
     * @return List of Item objects representing Service contacts
     */
    public static List<Item> getStakeholdersContacts(String caseId){
        if (!Schema.sObjectType.Service__c.isAccessible()) {
            //NÃO VALIDA ACESSO ESPECIFICO AOS CAMPOS
            throw new AuraHandledException('Sem acesso ao objeto Service__c ');
        }
        List<String> orderList = new List<String>();
        for (Order ord : [SELECT Id FROM Order WHERE CaseNumber__c = :caseId]) {
            orderList.add(ord.Id);
        }
        List<Item> allItems = new List<Item>();
        if (!onlyBookMarked) {
            for (Service__c ch : [SELECT Id, CreatedDate, CreatedById, CreatedBy.Name, Name, Order__c, Order__r.OrderNumber,
                                        RecordType.DeveloperName, RecordType.Name, Status__c, Type__c, StartDate__c,
                                        EndDate__c, Stakeholder__c, Stakeholder__r.Name, Situation__c, Description__c
            FROM Service__c
            WHERE Order__c IN :orderList
            AND DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate) AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            ORDER BY CreatedDate ASC]) {
                allItems.add(new Item('Service__c', ch, ch.CreatedDate,iconNames.get('Service__c'), false, false));
            }
        }
        else{
            for (Service__c ch : [SELECT Id, CreatedDate, CreatedById, CreatedBy.Name, Name, Order__c, Order__r.OrderNumber,
                                        RecordType.DeveloperName, RecordType.Name, Status__c, Type__c, StartDate__c,
                                        EndDate__c, Stakeholder__c, Stakeholder__r.Name, Situation__c, Description__c
            FROM Service__c
            WHERE Order__c IN :orderList
            AND DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate) AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate) AND Id in: bookMarked
            ORDER BY CreatedDate ASC]) {
                allItems.add(new Item('Service__c', ch, ch.CreatedDate,iconNames.get('Service__c'), false, false));
            }
        }
        return allItems;
    }

    /**
     * @description Retrieves all Comments__c records for a given Case within the configured date range
     * @param caseId ID of the Case record
     * @return List of Comments__c records
     */
    public static List<Comments__c> getComments(String caseId){
        List<Comments__c> comments = new List<Comments__c>();
        if (!onlyBookMarked) {
            comments = [SELECT Id,CreatedDate, CreatedById, message__c, comment__C
                        FROM Comments__c
                        WHERE Case__c =:caseId
                            AND DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate)
                            AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
                        ORDER BY CreatedDate ASC];
        } else {
            comments = [SELECT Id,CreatedDate, CreatedById, message__c, comment__C
                        FROM Comments__c
                        WHERE Case__c =:caseId
                            AND DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate)
                            AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
                            AND Id in: bookMarked
                        ORDER BY CreatedDate ASC];
        }
        return comments;
    }

    /**
     * @description Retrieves comments that do not start with the Hito prefix for the given Case
     * @param caseId ID of the Case record
     * @return List of Item objects representing non-Hito comments
     */
    public static List<Item> getCommentsWithoutHitos(String caseId){
        if (!Schema.sObjectType.Comments__c.isAccessible()) {
            //NÃO VALIDA ACESSO ESPECIFICO AOS CAMPOS
            throw new AuraHandledException('Sem acesso ao objeto Comments__c');
        }
        List<Item> allItems = new List<Item>();
        List<Comments__c> comments = getComments(caseId);
        for (Comments__c cc : comments) {
            if (cc.Comment__c != null && !cc.Comment__c.startsWith('Hito -')) {
                allItems.add(new Item('Comments__c', cc, cc.CreatedDate,iconNames.get('Comments__c'), false, false));
            }
        }
        return allItems;
    }

    /**
     * @description Retrieves comments that start with the Hito prefix for the given Case
     * @param caseId ID of the Case record
     * @return List of Item objects representing Hito comments
     */
    public static List<Item> getCommentsWithHitos(String caseId){
        if (!Schema.sObjectType.Comments__c.isAccessible()) {
            //NÃO VALIDA ACESSO ESPECIFICO AOS CAMPOS
            throw new AuraHandledException('Sem acesso ao objeto Comments__c');
        }
        List<Item> allItems = new List<Item>();
        List<Comments__c> comments = getComments(caseId);
        for (Comments__c cc : comments) {
            if (cc.Comment__c != null && cc.Comment__c.startsWith('Hito -')) {
                allItems.add(new Item('Comments__c', cc, cc.CreatedDate,iconNames.get('Comments__c'), false, false));
            }
        }
        return allItems;
    }

    /**
     * @description Retrieves Event records related to the given Case within the configured date range
     * @param caseId ID of the Case record
     * @return List of Item objects representing events
     */
    public static List<Item> getEvents(String caseId){
        if (!Schema.sObjectType.Event.isAccessible()) {
            //NÃO VALIDA ACESSO ESPECIFICO AOS CAMPOS
            throw new AuraHandledException('Sem acesso ao objeto Event');
        }
        List<Item> allItems = new List<Item>();
        if (!onlyBookMarked) {
            for (Event cc : [SELECT Id,CreatedDate, CreatedById,Subject,Location,StartDateTime,EndDateTime
            FROM Event
            WHERE WhatId =:caseId
            AND DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate)
            AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            ORDER BY CreatedDate ASC]) {
                allItems.add(new Item('Event', cc, cc.CreatedDate,iconNames.get('Event'), false, false));
            }
        }else{
            for (Event cc : [SELECT Id,CreatedDate, CreatedById,Subject,Location,StartDateTime,EndDateTime
            FROM Event
            WHERE WhatId =:caseId
            AND DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate)
            AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            AND Id in: bookMarked
            ORDER BY CreatedDate ASC]) {
                allItems.add(new Item('Event', cc, cc.CreatedDate,iconNames.get('Event'), false, false));
            }
        }
        return allItems;
    }

    /**
     * @description Retrieves Task records related to the given Case within the configured date range, excluding email subtypes
     * @param caseId ID of the Case record
     * @return List of Item objects representing tasks
     */
    public static List<Item> getTasks(String caseId){
        if (!Schema.sObjectType.Task.isAccessible()) {
            //NÃO VALIDA ACESSO ESPECIFICO AOS CAMPOS
            throw new AuraHandledException('Sem acesso ao objeto Task');
        }
        List<Item> allItems = new List<Item>();
        if (!onlyBookMarked) {
            for (Task tk : [SELECT Id,CreatedDate, CreatedById, CreatedBy.Name, Subject, WhatId, WhoId, What.Name, Who.Name,
                                   Theme__c, OwnerId, Owner.Name, ActivityDate, SubTheme__c, Status, Priority, Revision_date__c
            FROM Task
            WHERE WhatId =:caseId AND TaskSubtype != 'Email'
            AND DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate)
            AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            ORDER BY CreatedDate ASC]) {
                allItems.add(new Item('Task', tk, tk.CreatedDate,iconNames.get('Task'), false, false));
            }
        }else{
            for (Task tk : [SELECT Id,CreatedDate, CreatedById, CreatedBy.Name, Subject, WhatId, WhoId, What.Name, Who.Name,
                                   Theme__c, OwnerId, Owner.Name, ActivityDate, SubTheme__c, Status, Priority, Revision_date__c
            FROM Task
            WHERE WhatId =:caseId AND TaskSubtype != 'Email'
            AND DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate)
            AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            AND Id in: bookMarked
            ORDER BY CreatedDate ASC]) {
                allItems.add(new Item('Task', tk, tk.CreatedDate,iconNames.get('Task'), false, false));
            }
        }
        return allItems;
    }

    /**
     * @description Retrieves EmailMessage records related to the given Case within the configured date range
     * @param caseId ID of the Case record
     * @return List of Item objects representing email messages
     */
    public static List<Item> getEmails(String caseId){
        if (!Schema.sObjectType.EmailMessage.isAccessible()) {
            //NÃO VALIDA ACESSO ESPECIFICO AOS CAMPOS
            throw new AuraHandledException('Sem acesso ao objeto EmailMessage');
        }
        List<Item> allItems = new List<Item>();
        if (!onlyBookMarked) {
            for (EmailMessage em : [SELECT Id,CreatedDate,CreatedById,Subject,RelatedToId,HtmlBody,Incoming,HasAttachment
            ,ToAddress,FromAddress,
            (SELECT Id,RelationId,Relation.Name,RelationType,RelationAddress
            FROM EmailMessageRelations
            WHERE
            RelationId != null
            OR RelationType = 'BccAddress' order By RelationType asc, Relation.Name asc)
            FROM EmailMessage
            WHERE ParentId =:caseId
            AND DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate)
            AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            ORDER BY CreatedDate ASC]) {
                allItems.add(new Item('EmailMessage', em, em.CreatedDate,iconNames.get('EmailMessage'), true, true));
            }
        }else{
            for (EmailMessage em : [SELECT Id,CreatedDate,CreatedById,Subject,RelatedToId,HtmlBody,Incoming,HasAttachment
            ,ToAddress,FromAddress,
            (SELECT Id,RelationId,Relation.Name,RelationType,RelationAddress
            FROM EmailMessageRelations
            WHERE
            RelationId != null
            OR RelationType = 'BccAddress' order By RelationType asc, Relation.Name asc)
            FROM EmailMessage
            WHERE ParentId =:caseId
            AND DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate)
            AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            AND Id in: bookMarked
            ORDER BY CreatedDate ASC]) {
                allItems.add(new Item('EmailMessage', em, em.CreatedDate,iconNames.get('EmailMessage'), true, true));
            }
        }
        return allItems;
    }

    /**
     * @description Retrieves approval process history steps for the given Case within the configured date range
     * @param caseId ID of the Case record
     * @return List of Item objects representing approval steps
     */
    public static List<Item> getApprovals(String caseId){

        List<Item> allItems = new List<Item>();
        Case c;
        if (!onlyBookMarked) {
            c = [SELECT Id,
            (SELECT ID,CreatedDate,CreatedById,StepStatus
            FROM ProcessSteps
            WHERE DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate)
            AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            ORDER BY CreatedDate ASC)
            FROM Case
            WHERE Id =:caseId];

        }else{
            c = [SELECT Id,
            (SELECT ID,CreatedDate,CreatedById,StepStatus
            FROM ProcessSteps
            WHERE DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate)
            AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            AND Id in: bookMarked
            ORDER BY CreatedDate ASC)
            FROM Case
            WHERE Id =:caseId];
        }

        for(ProcessInstanceHistory pi : c.ProcessSteps)  {
            allItems.add(new Item('ProcessInstanceHistory', pi, pi.CreatedDate,iconNames.get('ProcessInstanceHistory'), false, false));
        }
        return allItems;
    }

    /**
     * @description Retrieves Order records related to the given Case within the configured date range
     * @param caseId ID of the Case record
     * @return List of Item objects representing orders
     */
    public static List<Item> getServicos(String caseId){
        if (!Schema.sObjectType.Order.isAccessible()) {
            //NÃO VALIDA ACESSO ESPECIFICO AOS CAMPOS
            throw new AuraHandledException('Sem acesso ao objeto Order');
        }
        List<Item> allItems = new List<Item>();
        List<Order> servicos = new List<Order>();
        if (!onlyBookMarked) {
            servicos  = [SELECT ID,OrderNumber,CreatedDate,CreatedById,CreatedBy.Name,Account.Name,Status,Type,
                                ProviderType__c,Guild__c,ContactDateTime__c,VisitDateTime__c,
                                Urgent__c,VisitType__c,Reason__c,SubReason__c,UrlLinkStatus__c
            FROM Order
            WHERE DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate) AND
            DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate) AND
            CaseNumber__c =: caseId
            ORDER BY CreatedDate ASC];
        }else{
            System.debug(bookMarked);
            servicos  = [SELECT ID,OrderNumber,CreatedDate,CreatedById,CreatedBy.Name,Account.Name,Status,Type,
                                ProviderType__c,Guild__c,ContactDateTime__c,VisitDateTime__c,
                                Urgent__c,VisitType__c,Reason__c,SubReason__c,UrlLinkStatus__c
            FROM Order
            WHERE DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate)
            AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            AND CaseNumber__c =: caseId
            AND Id in: bookMarked
            ORDER BY CreatedDate ASC];
        }

        for(Order t : servicos)  {
            allItems.add(new Item('Order', t, t.CreatedDate,iconNames.get('Order'), false, false));
        }
        return allItems;
    }

    /**
     * @description Retrieves Stakeholders__c records related to the given Case within the configured date range
     * @param caseId ID of the Case record
     * @return List of Item objects representing stakeholders
     */
    public static List<Item> getStakeholders(String caseId){
        if (!Schema.sObjectType.Stakeholders__c.isAccessible()) {
            //NÃO VALIDA ACESSO ESPECIFICO AOS CAMPOS
            throw new AuraHandledException('Sem acesso ao objeto Stakeholders__c');
        }
        List<Item> allItems = new List<Item>();
        List<Stakeholders__c> Stakeholders = new List<Stakeholders__c>();
        if (!onlyBookMarked) {
            Stakeholders  = [SELECT ID,Name,CreatedDate,CreatedById,CreatedBy.Name,Designation__c,Description__c,
                                    StakeholderType__c,StakeholderTaxID__c,IdentifierType__c,Comments__c,
                                    InsuranceCompanyDescription__c,PolicyholderNumber__c,IsLiableCompany__c,
                                    OpposingInsuranceClaimReference__c
            FROM Stakeholders__c
            WHERE DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate) AND
            DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate) AND
            Case__c =: caseId
            ORDER BY CreatedDate ASC];
        }else{
            System.debug(bookMarked);
            Stakeholders  = [SELECT ID,Name,CreatedDate,CreatedById,CreatedBy.Name,Designation__c,Description__c,
                                    StakeholderType__c,StakeholderTaxID__c,IdentifierType__c,Comments__c,
                                    InsuranceCompanyDescription__c,PolicyholderNumber__c,IsLiableCompany__c,
                                    OpposingInsuranceClaimReference__c
            FROM Stakeholders__c
            WHERE DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate)
            AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            AND Case__c =: caseId
            AND Id in: bookMarked
            ORDER BY CreatedDate ASC];
        }

        for(Stakeholders__c t : Stakeholders)  {
            allItems.add(new Item('Stakeholders__c', t, t.CreatedDate,iconNames.get('Stakeholders__c'), false, false));
        }
        return allItems;
    }

    /*ublic static List<Item> getStakeholdersContact(String caseId){
        if (!Schema.sObjectType.Service__c.isAccessible()) {
            //NÃO VALIDA ACESSO ESPECIFICO AOS CAMPOS
            throw new AuraHandledException('Sem acesso ao objeto Service__c');
        }
        List<Item> allItems = new List<Item>();
        List<Service__c> services = new List<Service__c>();
        List<String> listIdsRelatedOrderCase = new List<String>();
        for (Order eorder : [SELECT Id FROM Order WHERE CaseNumber__c = :caseId]) {
            listIdsRelatedOrderCase.add(eorder.Id);
        }
        if (!onlyBookMarked) {
            services = [SELECT ID,Name,CreatedDate,CreatedById,Order__c,Order__r.OrderNumber
            FROM Service__c
            WHERE DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate) AND
            DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate) AND
            Order__c IN :listIdsRelatedOrderCase
            ORDER BY CreatedDate ASC];
        }else{
            System.debug(bookMarked);
            services = [SELECT ID,Name,CreatedDate,CreatedById,Order__c,Order__r.OrderNumber
            FROM Service__c
            WHERE DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate)
            AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            AND Order__c IN :listIdsRelatedOrderCase
            AND Id in: bookMarked
            ORDER BY CreatedDate ASC];
        }

        for(Service__c t : services)  {
            allItems.add(new Item('Service__c', t, t.CreatedDate,iconNames.get('Service__c'), false, false));
        }
        return allItems;
    }*/

    /**
     * @description Retrieves Incident records related to the given Case or its orders within the configured date range
     * @param caseId ID of the Case record
     * @return List of Item objects representing incidents
     */
    public static List<Item> getIncidencias(String caseId){
        if (!Schema.sObjectType.Incident.isAccessible()) {
            //NÃO VALIDA ACESSO ESPECIFICO AOS CAMPOS
            throw new AuraHandledException('Sem acesso ao objeto Incident');
        }
        List<Item> allItems = new List<Item>();
        List<Incident> Incidencias = new List<Incident>();
        List<String> listIdsRelatedOrderCase = new List<String>();
        for (Order eorder : [SELECT Id FROM Order WHERE CaseNumber__c = :caseId]) {
            listIdsRelatedOrderCase.add(eorder.Id);
        }
        if (!onlyBookMarked) {
            Incidencias  = [SELECT ID,IncidentNumber,Subject,CreatedDate,CreatedById,CreatedBy.Name,Type,Reason__c,
                                   Sub_Reason__c,EndDateTime,Status,OrderService__c,OrderService__r.OrderNumber,
                                   NestedCaseID__c,NestedCaseID__r.CaseNumber,Result__c,Origin__c,OwnerId,Owner.Name
            FROM Incident
            WHERE DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate) AND
            DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate) AND
            (NestedCaseID__c = :caseId OR OrderService__c IN :listIdsRelatedOrderCase)
            ORDER BY CreatedDate ASC];
        }else{
            System.debug(bookMarked);
            Incidencias  = [SELECT ID,IncidentNumber,Subject,CreatedDate,CreatedById,CreatedBy.Name,Type,Reason__c,
                                   Sub_Reason__c,EndDateTime,Status,OrderService__c,OrderService__r.OrderNumber,
                                   NestedCaseID__c,NestedCaseID__r.CaseNumber,Result__c,Origin__c,OwnerId,Owner.Name
            FROM Incident
            WHERE DAY_ONLY(CreatedDate) >= :Date.valueOf(filters.startDate)
            AND DAY_ONLY(CreatedDate) <= :Date.valueOf(filters.endDate)
            AND (NestedCaseID__c = :caseId OR OrderService__c IN :listIdsRelatedOrderCase)
            AND Id in: bookMarked
            ORDER BY CreatedDate ASC];
        }

        for(Incident t : Incidencias)  {
            allItems.add(new Item('Incident', t, t.CreatedDate,iconNames.get('Incident'), false, false));
        }
        return allItems;
    }

    /**
     * @description Loads all User records into the users map keyed by User ID
     */
    public static void getUsers(){
        if (!Schema.sObjectType.User.isAccessible()) {
            //NÃO VALIDA ACESSO ESPECIFICO AOS CAMPOS
            throw new AuraHandledException('Sem acesso ao objeto User');
        }

        for (User u : [Select Name,SmallPhotoUrl From User]) {
            users.put(u.Id, u);
        }
    }

    /**
     * @description Loads the bookmarked record IDs from the Favorites__c field of the given Case
     * @param caseId ID of the Case record
     */
    public static void getBookMarked(String caseId){
        String bookMarkedStr = [SELECT ID,Favorites__c FROM Case WHERE Id =: caseId limit 1].Favorites__c;
        bookMarked = bookMarkedStr != null ? bookMarkedStr.split(';') : new List<String>();
        System.debug(bookMarked);
    }

    /**
     * @description Returns the label of a field on a given sObject type
     * @param sObjectApiName API name of the sObject
     * @param fieldApiName API name of the field
     * @return String field label or the API name if not found
     */
    private static String getFieldLabel(String sObjectApiName, String fieldApiName) {
        if (String.isBlank(sObjectApiName) || String.isBlank(fieldApiName)) {
            return fieldApiName;
        }
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(sObjectApiName);
        if (sObjectType == null) {
            return fieldApiName;
        }
        Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
        if (fieldMap.containsKey(fieldApiName)) {
            return fieldMap.get(fieldApiName).getDescribe().getLabel();
        }
        return fieldApiName;
    }

    /**
     * @description Returns the label of the given sObject type
     * @param sObjectApiName API name of the sObject
     * @return String object label or the API name if not found
     */
    private static String getObjectLabel(String sObjectApiName) {
        if (String.isBlank(sObjectApiName)) {
            return sObjectApiName;
        }
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(sObjectApiName);
        if (sObjectType == null) {
            return sObjectApiName;
        }
        return sObjectType.getDescribe().getLabel();
    }

    /**
     * @description Resolves the display value for a history field, translating picklist API values to labels
     * @param sObjectApiName API name of the parent sObject
     * @param fieldApiName API name of the tracked field
     * @param rawValue Raw value from the history record
     * @return String display-friendly value
     */
    public static String getHistoryDisplayValue(String sObjectApiName, String fieldApiName, Object rawValue) {
        if (rawValue == null) {
            return null;
        }
        if (String.isBlank(sObjectApiName) || String.isBlank(fieldApiName)) {
            return String.valueOf(rawValue);
        }
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(sObjectApiName);
        if (sObjectType == null) {
            return String.valueOf(rawValue);
        }
        Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldApiName)) {
            return String.valueOf(rawValue);
        }
        Schema.DescribeFieldResult dfr = fieldMap.get(fieldApiName).getDescribe();
        if (dfr.getType() == Schema.DisplayType.Picklist || dfr.getType() == Schema.DisplayType.MultiPicklist) {
            String valueStr = String.valueOf(rawValue);
            if (dfr.getType() == Schema.DisplayType.MultiPicklist) {
                List<String> labels = new List<String>();
                for (String v : valueStr.split(';')) {
                    labels.add(getPicklistLabel(sObjectApiName, fieldApiName, v));
                }
                return String.join(labels, ';');
            }
            return getPicklistLabel(sObjectApiName, fieldApiName, valueStr);
        }
        return String.valueOf(rawValue);
    }

    /**
     * @description Returns the name of a stakeholder contact by ID
     * @param stakeholderContactId ID of the stakeholder contact
     * @return String stakeholder contact name or the ID itself
     */
    private static String getStakeholderContactName(String stakeholderContactId) {
        /*
        if (String.isBlank(stakeholderContactId)) {
            return stakeholderContactId;
        }
        if (stakeholderContactsById != null && stakeholderContactsById.containsKey(stakeholderContactId)) {
            return stakeholderContactsById.get(stakeholderContactId).Name;
        }
        return stakeholderContactId;
        */
        return stakeholderContactId;
    }

    /*private static String getStakeholderContactOrderNumber(String stakeholderContactId) {
        /*
        if (String.isBlank(stakeholderContactId)) {
            return null;
        }
        if (stakeholderContactsById != null && stakeholderContactsById.containsKey(stakeholderContactId)) {
            StakeholderContacts__c stakeholder = stakeholderContactsById.get(stakeholderContactId);
            return stakeholder.Order__r != null ? stakeholder.Order__r.OrderNumber : null;
        }
        return null;
        
        return null;
    }*/

    /**
     * @description Returns the label of a picklist value for a given sObject field
     * @param sObjectApiName API name of the sObject
     * @param fieldApiName API name of the picklist field
     * @param value API value to resolve
     * @return String picklist label or the original value if not found
     */
    public static String getPicklistLabel(String sObjectApiName, String fieldApiName, String value) {
        if (String.isBlank(sObjectApiName) || String.isBlank(fieldApiName) || value == null) {
            return value;
        }
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(sObjectApiName);
        if (sObjectType == null) {
            return value;
        }
        Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldApiName)) {
            return value;
        }
        Schema.DescribeFieldResult dfr = fieldMap.get(fieldApiName).getDescribe();
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe.getValue() == value) {
                return pe.getLabel();
            }
        }
        return value;
    }

    private static String getFieldDisplayValue(String sObjectApiName, String fieldApiName, Object rawValue) {
        if (rawValue == null) {
            return null;
        }

        if (rawValue instanceof Boolean) {
            return ((Boolean) rawValue) ? 'Sí' : 'No';
        }

        if (!String.isBlank(sObjectApiName) && !String.isBlank(fieldApiName)) {
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(sObjectApiName);
            if (sObjectType != null) {
                Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
                if (fieldMap.containsKey(fieldApiName)) {
                    Schema.DescribeFieldResult dfr = fieldMap.get(fieldApiName).getDescribe();
                    if (dfr.getType() == Schema.DisplayType.Picklist || dfr.getType() == Schema.DisplayType.MultiPicklist) {
                        return getHistoryDisplayValue(sObjectApiName, fieldApiName, rawValue);
                    }
                }
            }
        }

        if (rawValue instanceof Datetime) {
            return ((Datetime) rawValue).format();
        }
        if (rawValue instanceof Date) {
            return ((Date) rawValue).format();
        }

        return String.valueOf(rawValue);
    }

    private static void addFieldIfPresent(List<Field> fields, String label, String value) {
        if (!String.isBlank(value)) {
            fields.add(new Field(label, value, ''));
        }
    }

    private static void addFieldIfPresent(List<Field> fields, String sObjectApiName, String fieldApiName, Object rawValue) {
        addFieldIfPresent(fields, getFieldLabel(sObjectApiName, fieldApiName), getFieldDisplayValue(sObjectApiName, fieldApiName, rawValue));
    }

    private static String buildCreationTitle(String prefix, String mainValue, String secondaryValue) {
        List<String> parts = new List<String>();
        if (!String.isBlank(prefix)) {
            parts.add(prefix);
        }
        if (!String.isBlank(mainValue)) {
            parts.add(mainValue);
        }
        if (!String.isBlank(secondaryValue)) {
            parts.add(secondaryValue);
        }
        return parts.isEmpty() ? prefix : String.join(parts, ' ');
    }

    /**
     * @description Generates the display title for a timeline item based on the sObject type
     * @param sObjectType API name of the sObject type
     * @param obj The sObject record
     * @return String formatted title for the timeline item
     */
    public static String getTitle(String sObjectType, SObject obj){
        switch on sObjectType {
            when 'CaseHistory' {
                CaseHistory ch = (CaseHistory) obj;
                if( ch.Field == 'created'){
                    return Label.ProcessCreated;
                }else{
                    return Label.Updated_process_status;
                }
            }
            when 'OrderHistory' {
                OrderHistory ch = (OrderHistory) obj;
                String orderNumber = (ch.Order != null) ? ch.Order.OrderNumber : null;
                String guild = (ch.Order != null) ? getFieldDisplayValue('Order', 'Guild__c', ch.Order.Guild__c) : null;
                if( ch.Field == 'created'){
                    return buildCreationTitle(Label.HistoryNew + ' ' + getObjectLabel('Order'), orderNumber, guild);
                }else{
                    return buildCreationTitle(Label.HistoryUpdated + ' ' + getObjectLabel('Order'), orderNumber, guild);
                }
            }

            when 'Service__History' {
                Service__History ch = (Service__History) obj;
                if( ch.Field == 'created'){
                    return Label.HistoryNew + ' ' + getObjectLabel('Service__c');
                }else{
                    return Label.HistoryUpdated + ' ' + getObjectLabel('Service__c');
                }
            }
            when 'Comments__c'{
                Comments__c cm = (Comments__c) obj;
                if (cm.Comment__c.contains('Hito')) {
                    return  cm.Comment__c;
                }else{
                    return Label.Newprocesscommentary + ' - ' + cm.Comment__c;
                }

            }

            when 'Incident'{
                Incident inc = (Incident) obj;
                return buildCreationTitle('Nueva incidencia', inc.IncidentNumber, inc.Subject);
            }
            when 'Service__c'{
                Service__c service = (Service__c) obj;
                return buildCreationTitle('Nuevo Servicio', service.Name,' - ' + getFieldDisplayValue('Service__c', 'Type__c', service.Type__c));
            }

            when 'Event'{
                Event ev = (Event) obj;
                return Label.Events + ' ' + ev.Subject;
            }
            when 'Task'{
                Task tk = (Task) obj;
                return buildCreationTitle('Tarea', tk.Subject, null);
            }
            when 'EmailMessage'{
                EmailMessage em = (EmailMessage) obj;
                return 'Email ' + (em.Incoming ? Label.received : Label.sent) + ' (' + em.Subject + ')';
            }
            when 'ProcessInstanceHistory'{
                ProcessInstanceHistory pih = (ProcessInstanceHistory) obj;
                switch on pih.StepStatus {
                    when 'Started' {
                        return Label.Applicationforapprovalsubmitted;
                    }
                    when 'Approved' {
                        return Label.Processvalidation;
                    }
                    when 'Pending' {
                        return Label.Processvalidation;
                    }
                    when 'Rejected' {
                        return Label.Processvalidation;
                    }
                    when 'Removed' {
                        return Label.Processvalidation;
                    }
                    when else {
                        return '';
                    }
                }
            }
            when 'Order'{
                Order o = (Order) obj;
                return buildCreationTitle('Nuevo encargo', o.OrderNumber, getFieldDisplayValue('Order', 'Guild__c', o.Guild__c));
            }
            when 'Stakeholders__c'{
                Stakeholders__c s = (Stakeholders__c) obj;
                return buildCreationTitle('Nuevo Interesado', s.Name, null);
            }
            when else {
                return '';
            }
        }
    }

    /**
     * @description Generates the header body text for a timeline item, such as status transition descriptions
     * @param sObjectType API name of the sObject type
     * @param obj The sObject record
     * @return String header body text
     */
    public static String getHeaderBody(String sObjectType, SObject obj){
        switch on sObjectType {
            when 'CaseHistory' {
                CaseHistory ch = (CaseHistory) obj;
                if( ch.Field == 'created'){
                    return '';
                }else{
                    String de = getPicklistLabel('Case', 'Status', String.valueOf(ch.OldValue));
                    String para = getPicklistLabel('Case', 'Status', String.valueOf(ch.NewValue));
                    if (ch.OldValue!= null ) {
                        return Label.State + ' ' + de + ' ' +  Label.To + ' '+ para;
                    }
                }
            }

        }
        return '';
    }

    /**
     * @description Builds the list of detail fields displayed in the timeline item body for a given sObject type
     * @param sObjectType API name of the sObject type
     * @param obj The sObject record
     * @return List of Field objects containing name-value pairs for display
     */
    public static List<Field> getBodyFields(String sObjectType, SObject obj){
        List<Field> fields = new List<Field>();

        switch on sObjectType {
            when 'CaseHistory' {
                CaseHistory ch = (CaseHistory) obj;
            }
            when 'OrderHistory' {
                OrderHistory oh = (OrderHistory) obj;
                if (oh.OldValue != null && oh.NewValue != null) {
				    fields.add(new Field(Label.Field, getFieldLabel('Order', oh.Field),''));
					fields.add(new Field(Schema.SObjectType.OrderHistory.fields.OldValue.getLabel(), getHistoryDisplayValue('Order', oh.Field, oh.OldValue),''));
					fields.add(new Field(Schema.SObjectType.OrderHistory.fields.NewValue.getLabel(), getHistoryDisplayValue('Order', oh.Field, oh.NewValue),''));

                }
            }

            when 'Service__History' {
                Service__History oh = (Service__History) obj;
                if (oh.OldValue != null && oh.NewValue != null) {
			    fields.add(new Field(Label.Field, getFieldLabel('Service__c', oh.Field),''));
				fields.add(new Field(Schema.SObjectType.Service__History.fields.OldValue.getLabel(), getHistoryDisplayValue('Service__c', oh.Field, oh.OldValue),''));
				fields.add(new Field(Schema.SObjectType.Service__History.fields.NewValue.getLabel(), getHistoryDisplayValue('Service__c', oh.Field, oh.NewValue),''));
                }
            }

            when 'Comments__c'{
                Comments__c cc = (Comments__c) obj;
                if (cc.message__c != null) {
                    fields.add(new Field(getFieldLabel('Comments__c', 'Message__c'), cc.message__c,''));
                }

                if(!cc.Comment__c.contains('Hito')){
                    fields.add(new Field(getFieldLabel('Comments__c', 'Comment__c'), cc.Comment__c,''));
                }

            }

            when 'Event' {
                Event ev = (Event) obj;
                fields.add(new Field(Label.Subject, ev.Subject,''));
                fields.add(new Field(Label.Location, ev.Location,''));
                fields.add(new Field(Label.Start, ev.StartDateTime.format(),''));
                fields.add(new Field(Label.End, ev.EndDateTime.format(),''));
            }
            when 'EmailMessage' {
                EmailMessage em = (EmailMessage) obj;
                if(em.HtmlBody.contains('--------------- '+ Label.Originalmessage +' ---------------')){
                    fields.add(new Field(Label.Email_body, em.HtmlBody,'',em.HtmlBody.split('--------------- '+ Label.Originalmessage +' ---------------')[0],'--------------- '+ Label.Originalmessage +' ---------------'+ em.HtmlBody.split('--------------- '+ Label.Originalmessage +' ---------------')[1]));
                }else{
                    System.debug(false);
                    fields.add(new Field(Label.Email_body, em.HtmlBody,''));
                }
            }
            when 'Order' {
                Order o = (Order) obj;
                addFieldIfPresent(fields, 'Order', 'OrderNumber', o.OrderNumber);
                addFieldIfPresent(fields, 'Order', 'Status', o.Status);
                addFieldIfPresent(fields, 'Order', 'Type', o.Type);
                addFieldIfPresent(fields, 'Order', 'ProviderType__c', o.ProviderType__c);
                addFieldIfPresent(fields, 'Order', 'Guild__c', o.Guild__c);
                addFieldIfPresent(fields, getFieldLabel('Order', 'AccountId'), o.Account != null ? o.Account.Name : null);
                addFieldIfPresent(fields, 'Order', 'ContactDateTime__c', o.ContactDateTime__c);
                addFieldIfPresent(fields, 'Order', 'VisitDateTime__c', o.VisitDateTime__c);
                addFieldIfPresent(fields, 'Order', 'Urgent__c', o.Urgent__c);
                addFieldIfPresent(fields, 'Order', 'VisitType__c', o.VisitType__c);
                addFieldIfPresent(fields, 'Order', 'Reason__c', o.Reason__c);
                addFieldIfPresent(fields, 'Order', 'SubReason__c', o.SubReason__c);
                addFieldIfPresent(fields, 'Order', 'UrlLinkStatus__c', o.UrlLinkStatus__c);
            }
            when 'Stakeholders__c' {
                Stakeholders__c s = (Stakeholders__c) obj;
                addFieldIfPresent(fields, 'Stakeholders__c', 'Name', s.Name);
                addFieldIfPresent(fields, 'Stakeholders__c', 'StakeholderType__c', s.StakeholderType__c);
                addFieldIfPresent(fields, 'Stakeholders__c', 'StakeholderTaxID__c', s.StakeholderTaxID__c);
                addFieldIfPresent(fields, 'Stakeholders__c', 'IdentifierType__c', s.IdentifierType__c);
                addFieldIfPresent(fields, 'Stakeholders__c', 'Comments__c', s.Comments__c);
                addFieldIfPresent(fields, 'Stakeholders__c', 'InsuranceCompanyDescription__c', s.InsuranceCompanyDescription__c);
                addFieldIfPresent(fields, 'Stakeholders__c', 'PolicyholderNumber__c', s.PolicyholderNumber__c);
                addFieldIfPresent(fields, 'Stakeholders__c', 'IsLiableCompany__c', s.IsLiableCompany__c);
                addFieldIfPresent(fields, 'Stakeholders__c', 'Designation__c', s.Designation__c);
                addFieldIfPresent(fields, 'Stakeholders__c', 'OpposingInsuranceClaimReference__c', s.OpposingInsuranceClaimReference__c);
                addFieldIfPresent(fields, 'Stakeholders__c', 'CreatedDate', s.CreatedDate);
                addFieldIfPresent(fields, 'Stakeholders__c', 'CreatedById', s.CreatedBy != null ? s.CreatedBy.Name : null);

            }

            when 'Service__c' {
                Service__c s = (Service__c) obj;
                addFieldIfPresent(fields, 'Service__c', 'Order__c', s.Order__r != null ? s.Order__r.OrderNumber : null);
                addFieldIfPresent(fields, 'Service__c', 'Name', s.Name);
                addFieldIfPresent(fields, 'Service__c', 'Status__c', s.Status__c);
                addFieldIfPresent(fields, 'Service__c', 'Type__c', s.Type__c);
                addFieldIfPresent(fields, 'Service__c', 'StartDate__c', s.StartDate__c);
                addFieldIfPresent(fields, 'Service__c', 'EndDate__c', s.EndDate__c);
                addFieldIfPresent(fields, 'Service__c', 'Stakeholder__c', s.Stakeholder__r != null ? s.Stakeholder__r.Name : null);
                addFieldIfPresent(fields, 'Service__c', 'Situation__c', s.Situation__c);
                addFieldIfPresent(fields, 'Service__c', 'Description__c', s.Description__c);
                addFieldIfPresent(fields, 'Service__c', 'CreatedDate', s.CreatedDate);
                addFieldIfPresent(fields, 'Service__c', 'CreatedById', s.CreatedBy != null ? s.CreatedBy.Name : null);
            }
            when 'Incident' {
                Incident i = (Incident) obj;
                addFieldIfPresent(fields, 'Incident', 'IncidentNumber', i.IncidentNumber);
                addFieldIfPresent(fields, 'Incident', 'Type', i.Type);
                addFieldIfPresent(fields, 'Incident', 'Reason__c', i.Reason__c);
                addFieldIfPresent(fields, 'Incident', 'Sub_Reason__c', i.Sub_Reason__c);
                addFieldIfPresent(fields, 'Incident', 'EndDateTime', i.EndDateTime);
                addFieldIfPresent(fields, 'Incident', 'Status', i.Status);
                addFieldIfPresent(fields, 'Incident', 'OrderService__c', i.OrderService__r != null ? i.OrderService__r.OrderNumber : null);
                addFieldIfPresent(fields, 'Incident', 'Result__c', i.Result__c);
                addFieldIfPresent(fields, 'Incident', 'Origin__c', i.Origin__c);
                addFieldIfPresent(fields, 'Incident', 'OwnerId', i.Owner != null ? i.Owner.Name : null);
                addFieldIfPresent(fields, 'Incident', 'CreatedDate', i.CreatedDate);
                addFieldIfPresent(fields, 'Incident', 'CreatedById', i.CreatedBy != null ? i.CreatedBy.Name : null);
            }

            when 'Task' {
                Task tk = (Task) obj;
                addFieldIfPresent(fields, 'Task', 'Subject', tk.Subject);
                addFieldIfPresent(fields, 'Task', 'Theme__c', tk.Theme__c);
                addFieldIfPresent(fields, 'Task', 'OwnerId', tk.Owner != null ? tk.Owner.Name : null);
                addFieldIfPresent(fields, 'Task', 'ActivityDate', tk.ActivityDate);
                addFieldIfPresent(fields, 'Task', 'SubTheme__c', tk.SubTheme__c);
                addFieldIfPresent(fields, 'Task', 'Status', tk.Status);
                addFieldIfPresent(fields, 'Task', 'Priority', tk.Priority);
                addFieldIfPresent(fields, 'Task', 'Revision_date__c', tk.Revision_date__c);
                addFieldIfPresent(fields, 'Task', 'CreatedDate', tk.CreatedDate);
                addFieldIfPresent(fields, 'Task', 'CreatedById', tk.CreatedBy != null ? tk.CreatedBy.Name : null);
            }


        }

        return fields;
    }

    public class Item implements Comparable {
        @AuraEnabled
        public string sObjectType;
        @AuraEnabled
        public SObject obj;
        @AuraEnabled
        public String activityId;
        @AuraEnabled
        public String switchClass;
        @AuraEnabled
        public DateTime itemDate;
        @AuraEnabled
        public String itemDateString;
        @AuraEnabled
        public String iconName;
        @AuraEnabled
        public String containerClass;
        @AuraEnabled
        public String title;
        @AuraEnabled
        public String titleClass;
        @AuraEnabled
        public String bodyClass;
        @AuraEnabled
        public String headerBody;
        @AuraEnabled
        public String emailSubject;
        @AuraEnabled
        public User createdBy;
        @AuraEnabled
        public Boolean bigField;
        @AuraEnabled
        public Boolean isEmail;
        @AuraEnabled
        public Boolean hasAValidLink;
        @AuraEnabled
        public Boolean hasBcc;
        @AuraEnabled
        public Boolean hasAttachment;
        @AuraEnabled
        public Boolean hasContentToExpand;
        @AuraEnabled
        public Boolean isBookmarked;
        @AuraEnabled
        public Boolean hasRelationName;
        @AuraEnabled
        public List<EmailMessageRelation> emailMessageRelations;
        @AuraEnabled
        public List<Field> bodyFields;
        @AuraEnabled
        public List<EmailMessageRelation> emailToAddress;
        @AuraEnabled
        public List<EmailMessageRelation> emailBccAddress;
        @AuraEnabled
        public String emailToAddressStr;
        @AuraEnabled
        public String emailBccAddressStr;

        public Item(){

        }

        public Item(String sObjectType, SObject obj,DateTime itemDate,String iconName, Boolean bigField, Boolean isEmail){
            this.sObjectType = sObjectType;
            this.obj = obj;
            this.activityId = 'activity' + activityIndex;
            this.itemDate = itemDate;
            this.itemDateString = itemDate.format();
            this.iconName = iconName;
            this.containerClass = 'slds-timeline__item_expandable slds-timeline__item_'+ sObjectType;
            this.title = getTitle(sObjectType, obj);
            this.titleClass = (sObjectType == 'Case' || sObjectType == 'CaseHistory') ? 'title' : 'titleLinkNoBold';
            this.headerBody = getHeaderBody(sObjectType, obj);
            this.createdBy = users.get((String) obj.get('CreatedById'));
            this.bodyFields = getBodyFields(sObjectType, obj);
            this.switchClass = (bodyFields.isEmpty()) ? 'visibility:hidden;cursor: default;' : 'pointer-events: all!important';
            //this.switchClass = (bodyFields.isEmpty()) ? 'pointer-events:none;cursor: not-allowed;' : 'pointer-events: all!important';
            this.bodyClass = bookMarked.contains(obj.Id) ? 'bookMarkTexture slds-theme_alert-texture slds-theme_shade slds-media__body' : 'slds-media__body';
            this.hasContentToExpand = (bodyFields.isEmpty()) ? false : true;
            this.bigField = bigField;
            this.isBookmarked = bookMarked.contains(obj.Id);
            this.isEmail = isEmail;
            if (sObjectType == 'EmailMessage') {
                EmailMessage em = (EmailMessage) obj;
                this.emailToAddress = new List<EmailMessageRelation>();
                this.emailBccAddress = new List<EmailMessageRelation>();
                this.emailMessageRelations = em.EmailMessageRelations;
                this.emailSubject = em.Subject;
                for (EmailMessageRelation emr : em.EmailMessageRelations) {
                    if (emr.RelationType == 'ToAddress') {
                        this.emailToAddress.add(emr);
                    } else if (emr.RelationType == 'BccAddress') {
                        this.emailBccAddress.add(emr);
                    }
                }
                if(em.EmailMessageRelations.isEmpty()){
                    EmailMessageRelation emr = new EmailMessageRelation();
                    emr.RelationAddress = em.ToAddress;
                    this.hasRelationName = false;
                    this.emailToAddress.add(emr);
                }
                this.hasBcc = !this.emailBccAddress.isEmpty();
                this.emailToAddressStr = JSON.serialize(this.emailToAddress);
                this.emailBccAddressStr = JSON.serialize(this.emailBccAddress);
                this.hasAttachment = em.hasAttachment;
            }
            Boolean isHistory = sObjectType == 'CaseHistory'
                || sObjectType == 'OrderHistory'
                || sObjectType == 'Service__History'
                || sObjectType.endsWith('__History');
            if(!isHistory && sObjectType != 'CaseComment'){
                this.hasAValidLink = true;
            }else{
                this.hasAValidLink = false;
                this.titleClass = 'title';
            }
            activityIndex++;
        }

        public List<Item> filter(Filter filters){
            return null;
        }

        public Integer compareTo(Object compareTo) {
            if(this.itemDate == null || this.itemDate == ((Item) compareTo).itemDate){
                return 0;
            } else if(this.itemDate > ((Item) compareTo).itemDate){
                return -1;
            } else {
                return 1;
            }
        }
    }

    public class Field{
        public Field(String name,String value,String recordId){
            this.Name = name;
            this.Value = value;
            this.RecordId = recordId;
            this.FieldId = 'Field' + fieldIndex;
            fieldIndex++;
        }

        public Field(String name,String value,String recordId,String initialHtml, String fullHtml){
            this.Name = name;
            this.Value = value;
            this.RecordId = recordId;
            this.FieldId = 'Field' + fieldIndex;
            this.IsSplitedEmail = true;
            this.InitialHtml = initialHtml;
            this.FullHtml = fullHtml;
            fieldIndex++;
        }

        @AuraEnabled
        public String RecordId;
        @AuraEnabled
        public String Name;
        @AuraEnabled
        public String Value;
        @AuraEnabled
        public String FieldId;
        @AuraEnabled
        public Boolean IsSplitedEmail;
        @AuraEnabled
        public String InitialHtml;
        @AuraEnabled
        public String FullHtml;
        @AuraEnabled
        public Boolean showFullEmail;

    }

    public class Filter{
        @AuraEnabled
        public String startDate {get;set;}
        @AuraEnabled
        public String endDate {get;set;}
        @AuraEnabled
        public List<String> selectedObjets {get;set;}
    }
}