/**
 * @description       : Controller class for handling multi-record integration processes
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 04-03-2026
 * @last modified by  : Daniel Flores
**/

public with sharing class MultiRecordIntegrationController {
    /**
     * @description Starts the reprocessing batch for multiple records.
     * @author Daniel Flores | 04-03-2026
     * @param recordType
     * @param recordIds
     * @return String
     **/
    @AuraEnabled
    public static String reprocessMultipleRecords(String recordType, String recordIds){
        
        SObjectType recordSObjectType = ((SObject) Type.forName(recordType).newInstance()).getSObjectType();

        List<String> recordIdList = (List<String>)JSON.deserialize(recordIds, List<String>.class);
        Id jobId = Database.executeBatch(new IntegrationsReprocessingBatch(recordSObjectType, recordIdList, false), 1);
        return jobId;
    }

    /**
     * @description Returns the SObject API name for a given record Id.
     * @author Daniel Flores | 04-03-2026
     * @param recordIdString
     * @return String
     **/
    @AuraEnabled
    public static String getObjectType(String recordIdString){
        Id recordId = Id.valueOf(recordIdString);
        return recordId.getSObjectType().getDescribe().getName();
    }

    /**
     * @description Retrieves records by type and ids and returns them as wrappers.
     * @author Daniel Flores | 04-03-2026
     * @param recordType
     * @param recordIds
     * @return List<WrapperInterface>
     **/
    @AuraEnabled
    public static List<WrapperInterface> getRecords(String recordType, String recordIds){
        List<String> recordIdList = (List<String>)JSON.deserialize(recordIds, List<String>.class);
        if(recordType == Case.getSObjectType().getDescribe().getName()) {
            List<Case> records = [SELECT Id, CaseNumber,LastIntegrationDescription__c, Status, Contact.Name FROM Case WHERE Id IN :recordIdList];
            System.debug(records);
            return convertCaseToCaseWrapper(records);
        }
        else if(recordType == Order.getSObjectType().getDescribe().getName()){
            List<Order> records = [SELECT Id, Name, LastIntegrationDescription__c, Status, Type , OrderNumber FROM Order WHERE Id IN :recordIdList];
            System.debug(records);
            return convertOrderToOrderWrapper(records);

        }
        else {
            System.debug('Empty List');
            return new List<WrapperInterface>();
        }
    }

    /**
     * @description Retrieves all records with LastIntegration__c filled for a given type.
     * @author Daniel Flores | 04-03-2026
     * @param recordType
     * @return List<WrapperInterface>
     **/
    @AuraEnabled
    public static List<WrapperInterface> getAllRecords(String recordType){
        if(recordType == Case.getSObjectType().getDescribe().getName()) {
            List<Case> records = [SELECT Id, CaseNumber,LastIntegrationDescription__c, Status, Contact.Name FROM Case WHERE LastIntegration__c != null];
            return convertCaseToCaseWrapper(records);
           
        }
        else if(recordType == Order.getSObjectType().getDescribe().getName()){
            List<Order> records = [SELECT Id, Name, LastIntegrationDescription__c, Status, Type, OrderNumber FROM Order WHERE LastIntegration__c != null];
            return convertOrderToOrderWrapper(records);
       
        }
        else if(recordType == 'Service'){
            List<Service__c> records = [SELECT ID, LastIntegration__c, LastIntegrationDateTime__c, LastIntegrationDescription__c, Name, Status__c FROM Service__c WHERE LastIntegration__c != null];
            return convertServiceToServiceWrapper(records);
          
        }
        else {
            System.debug('Empty List');
            return new List<WrapperInterface>();
        }
    }
    
    /**
     * @description Returns details for a batch job (AsyncApexJob).
     * @author Daniel Flores | 04-03-2026
     * @param jobId
     * @return List<BatchDetailsWrapper>
     **/
    @AuraEnabled
    public static List<BatchDetailsWrapper> getJobDetails(String jobId){
        try {
            List<BatchDetailsWrapper> batchDetailsList = new List<BatchDetailsWrapper>();
            List<AsyncApexJob> asyncJobList = [SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors FROM AsyncApexJob where Id =: jobId ];
            for (AsyncApexJob batchJob : asyncJobList) {
                BatchDetailsWrapper batchDetails = new BatchDetailsWrapper();
                batchDetails.jobId = batchJob.Id;
                batchDetails.status = batchJob.Status;
                batchDetails.jobItemsProcessed = batchJob.JobItemsProcessed;
                batchDetails.totalJobItems = batchJob.TotalJobItems;
                batchDetails.numberOfErrors = batchJob.NumberOfErrors;
                batchDetailsList.add(batchDetails);
            }            
            return batchDetailsList;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Converts Case records into Case wrapper instances.
     * @author Daniel Flores | 04-03-2026
     * @param caseRecords
     * @return List<CaseWrapper>
     **/
    public static List<CaseWrapper> convertCaseToCaseWrapper(List<Case> caseRecords){
        List<CaseWrapper> caseWrapperList = new List<CaseWrapper>();
        Map<String, String> statusLabelMap = new Map<String, String>();
        for (Schema.PicklistEntry entry : Case.Status.getDescribe().getPicklistValues()) {
            statusLabelMap.put(entry.getValue(), entry.getLabel());
        }
        for(Case caseRecord : caseRecords){
            CaseWrapper caseWrapper = new CaseWrapper();
            caseWrapper.id = caseRecord.Id;
            caseWrapper.caseNumber = caseRecord.CaseNumber;
            caseWrapper.descritivoDaUltimaIntegracao = caseRecord.LastIntegrationDescription__c;
            caseWrapper.status = statusLabelMap.containsKey(caseRecord.Status) ? statusLabelMap.get(caseRecord.Status) : caseRecord.Status;
            caseWrapper.contactName = caseRecord.Contact.Name;
            caseWrapperList.add(caseWrapper);
        }
        return caseWrapperList;
    }

    /**
     * @description Converts Service records into Service wrapper instances.
     * @author Daniel Flores | 04-03-2026
     * @param serviceRecords
     * @return List<CaseWrapper>
     **/
    public static List<CaseWrapper> convertServiceToServiceWrapper(List<Service__c> serviceRecords){
        List<CaseWrapper> caseWrapperList = new List<CaseWrapper>();
        Map<String, String> statusLabelMap = new Map<String, String>();
        for (Schema.PicklistEntry entry : Service__c.Status__c.getDescribe().getPicklistValues()) {
            statusLabelMap.put(entry.getValue(), entry.getLabel());
        }
        for(Service__c serviceRecord : serviceRecords){
            CaseWrapper caseWrapper = new CaseWrapper();
            caseWrapper.id = serviceRecord.Id;
            caseWrapper.caseNumber = serviceRecord.Name;
            caseWrapper.descritivoDaUltimaIntegracao = serviceRecord.LastIntegrationDescription__c;
            caseWrapper.status = statusLabelMap.containsKey(serviceRecord.Status__c) ? statusLabelMap.get(serviceRecord.Status__c) : serviceRecord.Status__c;
            caseWrapperList.add(caseWrapper);
        }
        return caseWrapperList;
    }



    /**
     * @description Converts Order records into Order wrapper instances.
     * @author Daniel Flores | 04-03-2026
     * @param orderRecords
     * @return List<OrderWrapper>
     **/
    public static List<OrderWrapper> convertOrderToOrderWrapper(List<Order> orderRecords){
        List<OrderWrapper> orderWrapperList = new List<OrderWrapper>();
        Map<String, String> statusLabelMap = new Map<String, String>();
        for (Schema.PicklistEntry entry : Order.Status.getDescribe().getPicklistValues()) {
            statusLabelMap.put(entry.getValue(), entry.getLabel());
        }
        for(Order orderRecord : orderRecords){
            OrderWrapper orderWrapper = new OrderWrapper();
            orderWrapper.id = orderRecord.Id;
            orderWrapper.codigoServico = orderRecord.OrderNumber;
            orderWrapper.descritivoDaUltimaIntegracao = orderRecord.LastIntegrationDescription__c;
            orderWrapper.status = statusLabelMap.containsKey(orderRecord.Status) ? statusLabelMap.get(orderRecord.Status) : orderRecord.Status;
            orderWrapper.type = orderRecord.Type;
            orderWrapperList.add(orderWrapper);
        }
        return orderWrapperList;
    }

    public class BatchDetailsWrapper {
        @AuraEnabled
        public String jobId;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Integer jobItemsProcessed;
        @AuraEnabled
        public Integer totalJobItems;
        @AuraEnabled
        public Integer numberOfErrors;
    }

    public virtual class WrapperInterface {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String descritivoDaUltimaIntegracao;
        @AuraEnabled
        public String status;
    }

    public class CaseWrapper extends WrapperInterface {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String caseNumber;
        @AuraEnabled
        public String descritivoDaUltimaIntegracao;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String contactName;
    }

    public class OrderWrapper extends WrapperInterface {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String codigoServico;
        @AuraEnabled
        public String descritivoDaUltimaIntegracao;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String type;
    }

}