/**
 * @description       : Controller for document management including viewing, deleting, reassigning and emailing documents
 * @author            : Daniel Flores
 * @group             : Document Management
 * @last modified on  : 05-05-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class DocumentManagerController {
    // Constantes para prefixos de IDs Salesforce
    private static final String ORDER_PREFIX = '801';
    private static final String CASE_PREFIX = '500';
    private static final String CONTACT_PREFIX = '003';
    private static final String TASK_PREFIX = '00T';

    /**
     * @description Retorna lista de documentos relacionados a um registo
     * @param recordId ID do registo (Order, Case, Contact ou Task)
     * @return Lista de mapas contendo informações dos documentos
     * @throws AuraHandledException Se recordId for inválido
     */
    @AuraEnabled
    public static List<Map<String, Object>> getDocuments(String recordId) {
        if (String.isBlank(recordId)) {
            throw new AuraHandledException('Record ID não pode estar vazio');
        }
        
        try {
            String DisplayString = getDisplayStringByRecordType(recordId);
            
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId,
                    ContentDocument.Title,
                    ContentDocument.FileType,
                    ContentDocument.CreatedDate,
                    ContentDocument.CreatedBy.Name,
                    ContentDocument.LatestPublishedVersionId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId
            ];

            Set<Id> versionIds = new Set<Id>();
            Set<Id> documentIds = new Set<Id>();
            for (ContentDocumentLink cdl : links) {
                versionIds.add(cdl.ContentDocument.LatestPublishedVersionId);
                documentIds.add(cdl.ContentDocumentId);
            }

            Map<Id, ContentVersion> versionsMap = new Map<Id, ContentVersion>(
                [SELECT Id, DocumentType__c, DocumentPhase__c,  Description FROM ContentVersion WHERE Id IN :versionIds]
            );
            // Map picklist API value -> label for ContentVersion.DocumentType__c
            Map<String, String> docTypeValueToLabel = new Map<String, String>();
            try {
                Schema.SObjectField fieldRef = ContentVersion.DocumentType__c;
                Schema.DescribeFieldResult dfr = fieldRef.getDescribe();
                if (dfr != null && dfr.getType() == Schema.DisplayType.PICKLIST) {
                    for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
                        docTypeValueToLabel.put(pe.getValue(), pe.getLabel());
                    }
                }
            } catch (Exception ex) {
                // if describe fails for any reason, leave the map empty and fall back to API value
            }
            
            Map<Id, String> documentToOrderMap = new Map<Id, String>(); 
            Case caseRecord = null;
            
            if (recordId.startsWith(CASE_PREFIX)) { 
                
                List<ContentDocumentLink> allLinks = [
                    SELECT ContentDocumentId, LinkedEntityId
                    FROM ContentDocumentLink
                    WHERE ContentDocumentId IN :documentIds
                ];
                Set<Id> linkedEntityIds = new Set<Id>();
                for (ContentDocumentLink cdl : allLinks) {
                    linkedEntityIds.add(cdl.LinkedEntityId);
                }
                
                List<Order> relatedOrders = [SELECT Id, OrderNumber FROM Order WHERE Id IN :linkedEntityIds];
                for (Order ord : relatedOrders) {
                    for (ContentDocumentLink cdl : allLinks) {
                        if (cdl.LinkedEntityId == ord.Id) {
                            documentToOrderMap.put(cdl.ContentDocumentId, ord.OrderNumber);
                        }
                    }
                }
                
                List<Case> cases = [SELECT Id, CaseNumber FROM Case WHERE Id = :recordId LIMIT 1];
                caseRecord = cases.isEmpty() ? null : cases[0];
            } else if (recordId.startsWith(CONTACT_PREFIX)) {
                List<Contact> contacts = [SELECT Name FROM Contact WHERE Id = :recordId LIMIT 1];
                if (!contacts.isEmpty()) {
                    DisplayString = contacts[0].Name;
                }
            } else if (recordId.startsWith(TASK_PREFIX)) {
                List<Task> tasks = [SELECT Subject FROM Task WHERE Id = :recordId LIMIT 1];
                if (!tasks.isEmpty()) {
                    DisplayString = tasks[0].Subject;
                }
            }


            
            List<Map<String, Object>> result = new List<Map<String, Object>>();
            for (ContentDocumentLink cdl : links) {
                ContentVersion cv = versionsMap.get(cdl.ContentDocument.LatestPublishedVersionId);
                Map<String, Object> row = new Map<String, Object>();
                row.put('ContentDocumentId', cdl.ContentDocumentId);
                row.put('ContentVersionId', cdl.ContentDocument.LatestPublishedVersionId);
                String docTypeValue = (cv != null) ? cv.DocumentType__c : null;
                String docTypeLabel = docTypeValue;
                if (docTypeValue != null && docTypeValueToLabel.containsKey(docTypeValue)) {
                    docTypeLabel = docTypeValueToLabel.get(docTypeValue);
                }
                row.put('DocumentalType', docTypeLabel);
                row.put('viewLink', '/lightning/r/ContentDocument/' + cdl.ContentDocumentId + '/view');
                row.put('Comments', cv != null ? cv.Description : null);
                row.put('Title', cdl.ContentDocument.Title);
                row.put('FileType', cdl.ContentDocument.FileType);
                row.put('CreatedDate', cdl.ContentDocument.CreatedDate);
                row.put('CreatedByName', cdl.ContentDocument.CreatedBy.Name);
                row.put('DocumentalFase', cv.DocumentPhase__c);
                
                String orderRelated = '';
                if (recordId.startsWith(CASE_PREFIX) && documentToOrderMap.containsKey(cdl.ContentDocumentId)) {
                    orderRelated = documentToOrderMap.get(cdl.ContentDocumentId);
                } else if (recordId.startsWith(CASE_PREFIX) && caseRecord != null) {
                    orderRelated = caseRecord.CaseNumber;
                } else {
                    orderRelated = DisplayString;
                }
                row.put('OrderRelated', orderRelated);

                result.add(row);
            }

            return result;
        } catch (QueryException e) {
            throw new AuraHandledException('Erro ao buscar documentos: ' + e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Erro inesperado: ' + e.getMessage());
        }
    }

    /**
     * @description Pesquisa Tasks por Subject, CaseNumber, OrderNumber ou Contact Name
     * @param searchKey Texto para buscar no Subject, CaseNumber, OrderNumber ou Contact Name
     * @param limitSize Número máximo de resultados (padrão 50)
     * @return Lista de Tasks com campos: Id, Subject, Status, ActivityDate, Priority, RelatedRecord (CaseNumber, OrderNumber ou ContactName)
     */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> searchTasks(String searchKey, Integer limitSize) {
        searchKey = String.isBlank(searchKey) ? '' : searchKey;
        limitSize = (limitSize == null || limitSize <= 0) ? 50 : limitSize;
        
        String searchPattern = '%' + searchKey + '%';
        Set<Id> taskIds = new Set<Id>();
        
        // Buscar Tasks por Subject
        List<Task> tasksBySubject = [
            SELECT Id
            FROM Task
            WHERE Subject LIKE :searchPattern
            LIMIT :limitSize
        ];
        for (Task t : tasksBySubject) {
            taskIds.add(t.Id);
        }
        
        // Buscar Cases por CaseNumber e obter Tasks relacionadas
        List<Case> casesByNumber = [
            SELECT Id
            FROM Case
            WHERE CaseNumber LIKE :searchPattern
        ];
        Set<Id> caseIds = new Map<Id, Case>(casesByNumber).keySet();
        
        if (!caseIds.isEmpty()) {
            List<Task> tasksByCase = [
                SELECT Id
                FROM Task
                WHERE WhatId IN :caseIds
                LIMIT :limitSize
            ];
            for (Task t : tasksByCase) {
                taskIds.add(t.Id);
            }
        }
        
        // Buscar Orders por OrderNumber e obter Tasks relacionadas
        List<Order> ordersByNumber = [
            SELECT Id
            FROM Order
            WHERE OrderNumber LIKE :searchPattern
        ];
        Set<Id> orderIds = new Map<Id, Order>(ordersByNumber).keySet();
        
        if (!orderIds.isEmpty()) {
            List<Task> tasksByOrder = [
                SELECT Id
                FROM Task
                WHERE WhatId IN :orderIds
                LIMIT :limitSize
            ];
            for (Task t : tasksByOrder) {
                taskIds.add(t.Id);
            }
        }
        
        // Buscar Contacts por Name e obter Tasks relacionadas
        List<Contact> contactsByName = [
            SELECT Id
            FROM Contact
            WHERE Name LIKE :searchPattern
        ];
        Set<Id> contactIds = new Map<Id, Contact>(contactsByName).keySet();
        
        if (!contactIds.isEmpty()) {
            List<Task> tasksByContact = [
                SELECT Id
                FROM Task
                WHERE WhoId IN :contactIds
                LIMIT :limitSize
            ];
            for (Task t : tasksByContact) {
                taskIds.add(t.Id);
            }
        }
        
        // Limitar o resultado final
        List<Id> limitedTaskIds = new List<Id>(taskIds);
        Integer resultSize = Math.min(limitSize, limitedTaskIds.size());
        
        // Se não encontrou nada, retorna lista vazia
        if (resultSize == 0) {
            return new List<Map<String, Object>>();
        }
        
        // Buscar Tasks completas com dados necessários
        List<Task> tasks = [
            SELECT Id, Subject, Status, ActivityDate, Priority, WhatId, WhoId
            FROM Task
            WHERE Id IN :limitedTaskIds
            ORDER BY ActivityDate DESC
            LIMIT :resultSize
        ];
        
        // Coletar IDs para queries bulk
        Set<Id> finalCaseIds = new Set<Id>();
        Set<Id> finalOrderIds = new Set<Id>();
        Set<Id> finalContactIds = new Set<Id>();
        
        for (Task t : tasks) {
            if (t.WhatId != null) {
                String whatIdStr = String.valueOf(t.WhatId);
                if (whatIdStr.startsWith(CASE_PREFIX)) {
                    finalCaseIds.add(t.WhatId);
                } else if (whatIdStr.startsWith(ORDER_PREFIX)) {
                    finalOrderIds.add(t.WhatId);
                }
            }
            if (t.WhoId != null) {
                String whoIdStr = String.valueOf(t.WhoId);
                if (whoIdStr.startsWith(CONTACT_PREFIX)) {
                    finalContactIds.add(t.WhoId);
                }
            }
        }
        
        // Buscar dados dos registos relacionados
        Map<Id, Case> casesMap = new Map<Id, Case>();
        Map<Id, Order> ordersMap = new Map<Id, Order>();
        Map<Id, Contact> contactsMap = new Map<Id, Contact>();
        
        if (!finalCaseIds.isEmpty()) {
            casesMap = new Map<Id, Case>([SELECT Id, CaseNumber FROM Case WHERE Id IN :finalCaseIds]);
        }
        if (!finalOrderIds.isEmpty()) {
            ordersMap = new Map<Id, Order>([SELECT Id, OrderNumber FROM Order WHERE Id IN :finalOrderIds]);
        }
        if (!finalContactIds.isEmpty()) {
            contactsMap = new Map<Id, Contact>([SELECT Id, Name FROM Contact WHERE Id IN :finalContactIds]);
        }
        
        // Construir resultado
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Task t : tasks) {
            Map<String, Object> taskMap = new Map<String, Object>();
            taskMap.put('Id', t.Id);
            taskMap.put('Subject', t.Subject);
            taskMap.put('Status', t.Status);
            taskMap.put('ActivityDate', t.ActivityDate);
            taskMap.put('Priority', t.Priority);
            
            // Determinar o registo relacionado
            String relatedRecord = '';
            if (t.WhatId != null && casesMap.containsKey(t.WhatId)) {
                relatedRecord = casesMap.get(t.WhatId).CaseNumber;
            } else if (t.WhatId != null && ordersMap.containsKey(t.WhatId)) {
                relatedRecord = ordersMap.get(t.WhatId).OrderNumber;
            } else if (t.WhoId != null && contactsMap.containsKey(t.WhoId)) {
                relatedRecord = contactsMap.get(t.WhoId).Name;
            }
            
            taskMap.put('RelatedRecord', relatedRecord);
            result.add(taskMap);
        }
        
        return result;
    }



    /**
     * @description Deleta documentos da biblioteca de conteúdo
     * @param documentIds Lista de IDs de ContentDocument a deletar
     * @throws AuraHandledException Se a lista estiver vazia ou ocorrer erro
     */
    @AuraEnabled
    public static void deleteDocuments(List<Id> documentIds) {
        if (documentIds == null || documentIds.isEmpty()) {
            throw new AuraHandledException('Nenhum documento selecionado para deletar');
        }
        
        try {
            delete [SELECT Id FROM ContentDocument WHERE Id IN :documentIds];
        } catch (DmlException e) {
            throw new AuraHandledException('Erro ao deletar documentos: ' + e.getMessage());
        }
    }

    /**
     * @description Reatribui documentos de um registo para outro
     * @param documentIds Lista de IDs de ContentDocument
     * @param targetRecordId ID do registo de destino
     * @param recordId ID do registo de origem
     * @param orderId ID da Order (opcional)
     * @throws AuraHandledException Se parâmetros inválidos
     */
    @AuraEnabled
    public static void reassignDocuments(
        List<Id> documentIds,
        Id targetRecordId,
        String recordId,
        Id orderId
    ) {
        if (documentIds == null || documentIds.isEmpty() || String.isBlank(recordId) || targetRecordId == null) {
            throw new AuraHandledException('Documentos, registo de origem e destino são obrigatórios');
        }
        
        try {
            Set<Id> recordsToRemoveLinks = getRecordsToRemoveLinks(recordId);
            
            if (recordsToRemoveLinks.isEmpty()) {
                throw new AuraHandledException('Tipo de registo não reconhecido');
            }
            
            List<ContentDocumentLink> linksToDelete = [
                SELECT Id
                FROM ContentDocumentLink
                WHERE ContentDocumentId IN :documentIds
                AND LinkedEntityId IN :recordsToRemoveLinks
            ];

            if (!linksToDelete.isEmpty()) {
                delete linksToDelete;
            }

            Set<Id> existingLinks = new Map<Id, ContentDocumentLink>(
                [SELECT ContentDocumentId 
                FROM ContentDocumentLink 
                WHERE ContentDocumentId IN :documentIds 
                AND LinkedEntityId = :targetRecordId]
            ).keySet();

            List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
            for (Id docId : documentIds) {
                if (!existingLinks.contains(docId)) {
                    linksToInsert.add(new ContentDocumentLink(
                        ContentDocumentId = docId,
                        LinkedEntityId = targetRecordId,
                        ShareType = 'V',
                        Visibility = 'AllUsers'
                    ));

                    if (orderId != null) {
                        linksToInsert.add(new ContentDocumentLink(
                            ContentDocumentId = docId,
                            LinkedEntityId = orderId,
                            ShareType = 'V',
                            Visibility = 'AllUsers'
                        ));
                    }
                }
            }

            if (!linksToInsert.isEmpty()) {
                insert linksToInsert;
            }
        } catch (DmlException e) {
            throw new AuraHandledException('Erro ao reatribuir documentos: ' + e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Erro inesperado: ' + e.getMessage());
        }
    }
    
    /**
     * @description Método auxiliar para obter DisplayString baseado no tipo de registo
     * @param recordId ID do registo
     * @return String com informação do registo
     */
    private static String getDisplayStringByRecordType(String recordId) {
        if (recordId.startsWith(ORDER_PREFIX)) {
            List<Order> orders = [SELECT OrderNumber FROM Order WHERE Id = :recordId LIMIT 1];
            return orders.isEmpty() ? '' : orders[0].OrderNumber;
        } else if (recordId.startsWith(CONTACT_PREFIX)) {
            List<Contact> contacts = [SELECT Name FROM Contact WHERE Id = :recordId LIMIT 1];
            return contacts.isEmpty() ? '' : contacts[0].Name;
        } else if (recordId.startsWith(TASK_PREFIX)) {
            List<Task> tasks = [SELECT Subject FROM Task WHERE Id = :recordId LIMIT 1];
            return tasks.isEmpty() ? '' : tasks[0].Subject;
        }
        return '';
    }
    
    /**
     * @description Método auxiliar para obter registos a remover links
     * @param recordId ID do registo de origem
     * @return Set de IDs de registos relacionados
     */
    private static Set<Id> getRecordsToRemoveLinks(String recordId) {
        Set<Id> recordsToRemove = new Set<Id>();
        
        if (recordId.startsWith(CASE_PREFIX)) {
            recordsToRemove.add(recordId);
            List<Order> relatedOrders = [SELECT Id FROM Order WHERE CaseNumber__c = :recordId];
            for (Order o : relatedOrders) {
                recordsToRemove.add(o.Id);
            }
        } else if (recordId.startsWith(ORDER_PREFIX)) {
            List<Order> orders = [SELECT Id, CaseNumber__c FROM Order WHERE Id = :recordId LIMIT 1];
            if (!orders.isEmpty()) {
                recordsToRemove.add(orders[0].Id);
                if (orders[0].CaseNumber__c != null) {
                    recordsToRemove.add(orders[0].CaseNumber__c);
                }
            }
        } else if (recordId.startsWith(TASK_PREFIX) || recordId.startsWith(CONTACT_PREFIX)) {
            recordsToRemove.add(recordId);
        }
        
        return recordsToRemove;
    }

    /**
     * @description Retorna Orders relacionadas a uma Case
     * @param caseId ID da Case
     * @return Lista de Orders ordenadas
     */
    @AuraEnabled(cacheable=true)
    public static List<Order> getOrdersByCase(Id caseId) {
        if (caseId == null) {
            return new List<Order>();
        }
        return [SELECT Id, Name, OrderNumber 
                FROM Order 
                WHERE CaseNumber__c = :caseId 
                ORDER BY Name];
    }



    /**
     * @description Pesquisa Cases por CaseNumber
     * @param searchKey Número ou texto da Case
     * @return Lista de Cases encontradas
     */
    @AuraEnabled
    public static List<Case> searchCases(String searchKey) {
        if (String.isBlank(searchKey)) {
            return new List<Case>();
        }
        return [
            SELECT Id, CaseNumber
            FROM Case
            WHERE CaseNumber LIKE :('%' + searchKey + '%')
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
    }

    /**
     * @description Envia email com documentos anexados
     * @param recordId ID do registo para vincular ao email
     * @param toAddresses Endereços "para" (obrigatório)
     * @param ccAddresses Endereços "cc" (opcional)
     * @param bccAddresses Endereços "bcc" (opcional)
     * @param subject Assunto do email
     * @param body Corpo HTML do email
     * @param documentIds IDs dos documentos a anexar
     * @param orgWideEmailId ID do email corporativo (opcional)
     * @throws AuraHandledException Se toAddresses vazio ou erro ao enviar
     */
    @AuraEnabled
    public static void sendEmailWithDocuments(
        Id recordId,
        List<String> toAddresses,
        List<String> ccAddresses,
        List<String> bccAddresses,
        String subject,
        String body,
        List<Id> documentIds,
        Id orgWideEmailId
    ) {
        if (toAddresses == null || toAddresses.isEmpty()) {
            throw new AuraHandledException('Pelo menos um endereço de email "Para" é obrigatório');
        }
        
        try {
            List<ContentVersion> versions = [
                SELECT Id, Title, VersionData, FileExtension
                FROM ContentVersion
                WHERE ContentDocumentId IN :documentIds
                AND IsLatest = true
            ];

            List<Messaging.Emailfileattachment> attachments = new List<Messaging.Emailfileattachment>();
            for (ContentVersion v : versions) {
                Messaging.Emailfileattachment att = new Messaging.Emailfileattachment();
                String fileName = v.Title;
                if (v.FileExtension != null) {
                    fileName += '.' + v.FileExtension;
                }
                att.setFileName(fileName);
                att.setBody(v.VersionData);
                attachments.add(att);
            }

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(toAddresses);
            
            if (ccAddresses != null && !ccAddresses.isEmpty()) {
                email.setCcAddresses(ccAddresses);
            }
            if (bccAddresses != null && !bccAddresses.isEmpty()) {
                email.setBccAddresses(bccAddresses);
            }

            email.setSubject(String.isNotBlank(subject) ? subject : 'Email relativo ao registo ' + String.valueOf(recordId));
            email.setHtmlBody(String.isNotBlank(body) ? body : ' ');
            email.setWhatId(recordId);

            if (!attachments.isEmpty()) {
                email.setFileAttachments(attachments);
            }
            if (orgWideEmailId != null) {
                email.setOrgWideEmailAddressId(orgWideEmailId);
            }
            
            Messaging.sendEmail(new List<Messaging.Email>{ email });
        } catch (Exception e) {
            throw new AuraHandledException('Erro ao enviar email: ' + e.getMessage());
        }
    }

    /**
     * @description Retorna lista de EmailTemplates ativos
     * @return Templates disponíveis para usar
     */
    @AuraEnabled(cacheable=true)
    public static List<EmailTemplate> getEmailTemplates() {
        return [
            SELECT Id, Name
            FROM EmailTemplate
            WHERE IsActive = true
            ORDER BY Name
        ];
    }

    /**
     * @description Retorna endereços de email corporativos
     * @return OrgWideEmailAddresses disponíveis
     */
    @AuraEnabled(cacheable=true)
    public static List<OrgWideEmailAddress> getOrgWideEmails() {
        return [
            SELECT Id, Address, DisplayName
            FROM OrgWideEmailAddress
            ORDER BY DisplayName
        ];
    }
    /**
     * @description Retorna email do usuário atual
     * @return Email do usuário logado
     */
    @AuraEnabled(cacheable=true)
    public static String getCurrentUserEmail() {
        return UserInfo.getUserEmail();
    }





    /**
     * @description Retorna os labels dos campos da Task
     * @return Map com fieldName e field label
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getTaskFieldLabels() {
        Map<String, String> fieldLabels = new Map<String, String>();
        
        Schema.DescribeSObjectResult taskDescribe = Schema.SObjectType.Task;
        Map<String, Schema.SObjectField> fieldMap = taskDescribe.fields.getMap();
        
        // Obter labels dos campos específicos que usamos
        for (String fieldName : new List<String>{'Subject', 'Status', 'ActivityDate', 'Priority'}) {
            if (fieldMap.containsKey(fieldName)) {
                fieldLabels.put(fieldName, fieldMap.get(fieldName).getDescribe().getLabel());
            }
        }
        
        return fieldLabels;
    }

    /**
     * Wrapper para retornar subject e body de template renderizado
     */
    public class EmailTemplateWrapper {
        @AuraEnabled public String subject;
        @AuraEnabled public String htmlBody;
    }

    /**
     * @description Renderiza um EmailTemplate com dados do registo
     * @param templateId ID do EmailTemplate
     * @param recordId ID do registo para popular dados
     * @return Wrapper com subject e htmlBody renderizados
     * @throws AuraHandledException Se parâmetros inválidos ou erro ao renderizar
     */
    @AuraEnabled(cacheable=false)
    public static EmailTemplateWrapper applyEmailTemplate(Id templateId, Id recordId) {
        if (templateId == null || recordId == null) {
            throw new AuraHandledException('Template ID e Record ID são obrigatórios');
        }
        
        try {
            Messaging.SingleEmailMessage email =
                Messaging.renderStoredEmailTemplate(templateId, recordId, null);

            EmailTemplateWrapper wrap = new EmailTemplateWrapper();
            if (email != null) {
                wrap.subject  = email.getSubject();
                wrap.htmlBody = email.getHtmlBody();
            }
            return wrap;
        } catch (Exception e) {
            throw new AuraHandledException('Erro ao renderizar template: ' + e.getMessage());
        }
    }








}