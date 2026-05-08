/**
 * @description       : Controller for SMS messaging functionality with quick text support and Pelayo integration
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 09-04-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class NewSmsController {

    /**
    * @description Retrieves the main folder, its subfolders, and associated QuickText records.
    * @author Afonso Duque | 29-01-2026
    * @return QuickTextsFolderWrapper
    **/
    @AuraEnabled(cacheable=true)
    public static QuickTextsFolderWrapper getQuickTexts(String recordId){
        try {

            List<Case> caseList = [SELECT Id, GrandAccount__c FROM Case WHERE Id = :recordId LIMIT 1];
            if(!caseList.isEmpty()) {
                SMSSenderMapping__mdt smsMapping = SMSSenderMapping__mdt.getInstance(caseList[0].GrandAccount__c);
                if(smsMapping != null && smsMapping.Folder__c != null) {
                    List<Folder> mainFolder = [SELECT ID, Name, DeveloperName FROM Folder WHERE DeveloperName =:smsMapping.Folder__c LIMIT 1];
                    if(!mainFolder.isEmpty()) {
                        List<Folder> foldersList = [SELECT ID, Name, DeveloperName FROM Folder WHERE ParentID =: mainFolder[0].Id];
                        List<QuickText> quickTextsList = [SELECT ID, Name, Message, FolderId, Folder.DeveloperName FROM QuickText WHERE (FolderID IN : foldersList OR FolderId =: mainFolder[0].Id)];

                        return new QuickTextsFolderWrapper(mainFolder[0], foldersList, quickTextsList);
                    }
                }
            }

            return null;
        } catch (Exception e) {throw new AuraHandledException(e.getMessage());}
    }

    /**
    * @description Retrieves a Case record by its ID, including specified fields.
    * @author Afonso Duque | 29-01-2026
    * @param String recordId
    * @param List<String> fields
    * @return Case
    **/
    @AuraEnabled(cacheable=true)
    public static Case getCase(String recordId, List<String> fields) {
        try {
            String query = 'SELECT Id ';
            if(!fields.isEmpty()){
                query += ', ' + String.join(fields, ', ');
            }
            query = query.removeEnd(',') + ' FROM Case WHERE Id = :recordId LIMIT 1';

            System.debug('Query: ' + query);
            return Database.query(query);
        } catch (Exception e) {throw new AuraHandledException(e.getMessage());}
    }

    /**
    * @description Sends an SMS message and creates a Task record upon success.
    * @author Afonso Duque | 29-01-2026
    * @param String phoneNumber
    * @param String textMessage
    * @param Case recordCase
    * @param String recipientType
    * @return Boolean
    **/
    @AuraEnabled
    public static Boolean sendSMSMessage(String phoneNumber, String textMessage, Case recordCase, String recipientType) {
        try {

            String sender = SMSSenderMapping__mdt.getInstance(recordCase.GrandAccount__c).Sender__c;
            if (!phoneNumber.contains('+')) {
                phoneNumber = phoneNumber.startsWith('9') ? '+351' + phoneNumber : '+34' + phoneNumber;
                
            }
            SMSUtils.ServiceResponse messageResult = SMSUtils.sendSMSMessage(phoneNumber, textMessage, sender);

            if(messageResult.isSuccess) {
                Id commentId = createCaseComment(recordCase, phoneNumber, textMessage);
                // Notify Pelayo of the SMS communication (only for Pelayo cases)
                enqueuePelayoCommunication(recordCase.Id, commentId, phoneNumber, textMessage, recipientType);
            }
            return messageResult.isSuccess;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
    * @description Creates a CaseComment record to log the SMS message sent.
    * @author Afonso Duque | 30-01-2026
    * @param Case recordCase
    * @param String phoneNumber 
    * @param String textMessage
    * @return Id  The Id of the inserted Comments__c record
    **/
    public static Id createCaseComment(Case recordCase, String phoneNumber, String textMessage){
        Comments__c caseComment = new Comments__c(
            Case__c = recordCase.Id,
            Comment__c = 'Hito - Envío de SMS ' + phoneNumber,
            Message__c = textMessage,
            Type__c = 'Communications'
        );
        insert caseComment;
        return caseComment.Id;
    }

    /**
    * @description Enqueues the Pelayo communication service callout to notify Pelayo of the SMS.
    *              Only fires for Pelayo cases (GrandAccount__c = 'PLYO').
    * @author Daniel Flores | 01-04-2026
    * @param Id caseId
    * @param Id commentId
    * @param String phoneNumber
    * @param String textMessage
    * @param String recipientType
    **/
    private static void enqueuePelayoCommunication(Id caseId, Id commentId, String phoneNumber, String textMessage, String recipientType) {
        try {
            PelayoCommunicationService.enqueue(caseId, commentId, phoneNumber, textMessage, recipientType);
        } catch (Exception e) {
            // Best-effort: do not fail the SMS send if the Pelayo notification fails to enqueue
            System.debug(LoggingLevel.ERROR,
                'NewSmsController.enqueuePelayoCommunication error: ' + e.getMessage());
        }
    }

    /**
    * @description Retrieves active picklist values for a given object and field API name.
    * @param objectApiName The API name of the SObject
    * @param fieldApiName The API name of the picklist field
    * @return List<PicklistOption> List of active picklist label-value pairs
    **/
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getPicklistValues(String objectApiName, String fieldApiName) {
        try {
            List<PicklistOption> options = new List<PicklistOption>();

            if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) {
                return options;
            }

            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
            if (objectType == null) {
                return options;
            }

            Schema.SObjectField fieldToken = objectType.getDescribe().fields.getMap().get(fieldApiName);
            if (fieldToken == null) {
                return options;
            }

            for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
                if (entry.isActive()) {
                    options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
                }
            }

            return options;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
    * @description Creates a Task record to log the SMS message sent.
    * @author Afonso Duque | 29-01-2026
    * @param Case recordCase
    * @param String phoneNumber
    * @param String textMessage
    **/
    public static void createTask(Case recordCase, String phoneNumber, String textMessage){
        Task tsk = new Task(
            WhatId = recordCase.Id,
            OwnerId = recordCase.OwnerId,
            Priority = 'Média',
            Status = 'Completed',
            Subject = 'Envío de SMS a ' + phoneNumber,
            Description = textMessage
        );

        insert tsk;
    }

    public class QuickTextsFolderWrapper {
        @AuraEnabled public Folder mainFolder;
        @AuraEnabled public List<Folder> foldersList;
        @AuraEnabled public List<QuickText> quickTextsList;

        public QuickTextsFolderWrapper(Folder mainFolder, List<Folder> foldersList, List<QuickText> quickTextsList){
            this.mainFolder = mainFolder;
            this.foldersList = foldersList;
            this.quickTextsList = quickTextsList;
        }
    }

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
}