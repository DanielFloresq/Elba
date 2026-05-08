/**
 * @description       : Controller for creating contacts through the MKIS integration
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 20-08-2025
 * @last modified by  : Daniel Flores
**/
public with sharing class CreateContact {
    /**
     * @description Invocable method entry point for creating contacts from a Flow
     * @param parameters List of InputWrapper containing stakeholder contact details
     */
    @InvocableMethod(label='create Contact' description='Create Contact' )
    public static void createContactFlowUtils(List<InputWrapper> parameters) {
        /*
        List<String> strList = new List<String>();
        createContactMethod(parameters);
        */
    }

    /**
     * @description Processes the contact creation request by building the request body and routing to the appropriate method
     * @param parameters List of InputWrapper containing stakeholder and contact identifiers
     */
    public static void createContactMethod(List<InputWrapper> parameters){
        /*
        StakeholderContacts__c stakeHolderContact = [SELECT Order__c , ID,FirstContactDateTime__c,VisitDateTime__c,DetailDateTime__c,UnsuccessfulVisitDateTime__c,UnsuccessfulVisitReason__c, FirstUnsuccessfulContactDateTime__c,SecondUnsuccessfulContactDateTime__c,ThirdUnsuccessfulContactDateTime__c,UnsuccessfulContactReason__c  FROM StakeholderContacts__c WHERE Id =:parameters[0].idStakeHolderContact];
        createContactObj mkisContact = new createContactObj();
        mkisContact.order_id = stakeHolderContact.Order__c ;
        mkisContact.stakeholder_id = parameters[0].idStakeHolder;
        mkisContact.first_contact_at = Date.valueOf(stakeHolderContact.FirstContactDateTime__c); 
        mkisContact.failed_contact_reason_name = stakeHolderContact.UnsuccessfulContactReason__c;

        DateTime firstVisitDate  =  parameters[0].moments == 'm1' || parameters[0].moments == 'm4' ? stakeHolderContact.FirstUnsuccessfulContactDateTime__c : parameters[0].moments == 'm2' ? stakeHolderContact.SecondUnsuccessfulContactDateTime__c :  stakeHolderContact.ThirdUnsuccessfulContactDateTime__c;

        mkisContact.first_visit_at = firstVisitDate;
        mkisContact.visit_type_name = stakeHolderContact.DetailDateTime__c;
        mkisContact.external_id = stakeHolderContact.Id;
        String bodyRequest = JSON.serialize(mkisContact);  
        System.debug(bodyRequest);
        System.debug(parameters[0].moments);
        if (parameters[0].moments == 'm2' || parameters[0].moments == 'm3' || parameters[0].moments == 'm1') {
            createContactFutureMethod(bodyRequest);    
        }else{
            createContactMethod(bodyRequest, stakeHolderContact );
        }
        */
    }   

    /**
     * @description Asynchronous method that performs the HTTP callout to create a contact in MKIS
     * @param bodyRequest JSON-serialized request body containing contact details
     */
    @future(callout=true)
    public static void createContactFutureMethod(String bodyRequest) {
        /*
        Organization org = [SELECT IsSandbox FROM Organization];

        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(bodyRequest);
        String idStakeHolderContact = (String) resultMap.get('external_id');
        StakeholderContacts__c stakeHolderContact = [SELECT mkisIdFirstMoment__c, mkisIdSecondMoment__c,mkisIdThirdMoment__c, Order__c , ID,FirstContactDateTime__c,VisitDateTime__c,DetailDateTime__c,UnsuccessfulVisitDateTime__c,UnsuccessfulVisitReason__c, FirstUnsuccessfulContactDateTime__c,SecondUnsuccessfulContactDateTime__c,ThirdUnsuccessfulContactDateTime__c,UnsuccessfulContactReason__c  FROM StakeholderContacts__c WHERE Id =:idStakeHolderContact];


        //Obtem os metadados com o endpoint para a create new service
        WebServiceUtils__mdt endpointMdt = [SELECT Endpoint__c, Email__c, Password__c FROM WebServiceUtils__mdt WHERE Label = 'createContact' AND IsSandbox__c =: org.IsSandbox LIMIT 1];
        System.debug(endpointMdt);
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpointMdt.Endpoint__c);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        String token = WebServicesUtilities.login();
        request.setHeader('Authorization', 'Bearer ' + token);
        request.setBody(bodyRequest);

        HttpResponse response = http.send(request);
        System.debug(response.getBody());

        Map<String, Object> resultMap2 = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        Map<String, Object> dataMap = (Map<String, Object>) resultMap2.get('data');
        String idMkis = String.valueOf(dataMap.get('id'));
       
        if (response.getStatusCode() == 200) {
            if (stakeHolderContact.mkisIdFirstMoment__c == null) {
                stakeHolderContact.mkisIdFirstMoment__c = idMkis;
            }else if (stakeHolderContact.mkisIdSecondMoment__c == null) {
                stakeHolderContact.mkisIdSecondMoment__c = idMkis;
            }else{
                stakeHolderContact.mkisIdThirdMoment__c = idMkis;
            } 
            update stakeHolderContact;
        }
        */
    }
   
    /*
    public static void createContactMethod(String bodyRequest, StakeholderContacts__c stakeHolder) {
        Organization org = [SELECT IsSandbox FROM Organization];
        WebServiceUtils__mdt endpointMdt = [SELECT Endpoint__c, Email__c, Password__c FROM WebServiceUtils__mdt WHERE Label = 'createContact' AND IsSandbox__c =: org.IsSandbox LIMIT 1];
        System.debug(endpointMdt);
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpointMdt.Endpoint__c);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        String token = WebServicesUtilities.login();
        request.setHeader('Authorization', 'Bearer ' + token);
        request.setBody(bodyRequest);
        HttpResponse response = http.send(request);
        
        if (response.getStatusCode() == 200) {
            Map<String, Object> resultMap2 = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            Map<String, Object> dataMap = (Map<String, Object>) resultMap2.get('data');
            String idMkis = String.valueOf(dataMap.get('id'));
            stakeHolder.mkisIdFirstMoment__c = idMkis;
            update stakeHolder;
        } 
            
    }
    */



    public class InputWrapper {
        @InvocableVariable(label='StakeHolder Contact Id' )
        public String idStakeHolderContact;
        @InvocableVariable(label='StakeHolder Id' )
        public String idStakeHolder;
        @InvocableVariable(label='Moments m1, m2 or m3' )
        public String moments;
    }

    public class createContactObj{
        public String order_id;
        public String stakeholder_id;
        public Date first_contact_at;
        public String failed_contact_reason_name;
        public DateTime first_visit_at;
        public String participant;
        public String visit_type_name;
        public String external_id;
    }
}