/**
 * @description       : Controller for creating and updating stakeholder contact records through MKIS integration
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 20-01-2026
 * @last modified by  : Daniel Flores
**/
public  class CreateUpdateStakeHolderContactController {

    /**
     * @description Invocable entry point that delegates stakeholder contact creation/update to a future method
     * @param stakeHolderIds List of InputWrapper containing the stakeholder contact Id to process
     */
    @InvocableMethod(label='Create and Update Stakeholder Contact' description='Create and Update Stakeholder Contact in the Portal' )
    public static void CreateUpdateStakeHolderContactController(List<InputWrapper> stakeHolderIds) {
        createUpdateStakeHolderContactFuture(stakeHolderIds[0].stackHolderContactId);
    }

    /**
     * @description Future method that performs the HTTP callout to create or update a stakeholder contact in the external MKIS portal
     * @param id The Id of the StakeholderContacts__c record to process
     */
    @future(callout=true)
    public static void createUpdateStakeHolderContactFuture(String id){
        /*
        StakeholderContacts__c stakeHolderContact = [SELECT ID,VisitDateTime__c, UnsuccessfulVisitDateTime__c,Stakeholder__r.MKISId__c ,Order__c,  Contact__c, DetailDateTime__c, FirstUnsuccessfulContactDateTime__c, FirstContactDateTime__c, SecondUnsuccessfulContactDateTime__c, ThirdUnsuccessfulContactDateTime__c,  UnsuccessfulContactReason__c, UnsuccessfulVisitReason__c, mkisId__c FROM StakeholderContacts__c WHERE Id =:id ];
        Order order = [SELECT Id, OrderNumber FROM Order WHERE Id =:stakeHolderContact.Order__c LIMIT 1];
        Organization org = [SELECT IsSandbox FROM Organization];
        WebServiceUtils__mdt endpointMdt = [SELECT Endpoint__c FROM WebServiceUtils__mdt WHERE Label = 'CreateAndUpdateStakeHolderContact' AND IsSandbox__c  = :org.IsSandbox LIMIT 1 ];
        String token = WebServicesUtilities.login();

        requestBody request = new requestBody();
        request.service_number = order.OrderNumber;
        request.interlocutor = stakeHolderContact.Contact__c;
        request.intervener_id = stakeHolderContact.Stakeholder__r.MKISId__c;
        request.visit_data_hour = formatDatetimeToCustomString(stakeHolderContact.VisitDateTime__c);
        request.visit_detail = stakeHolderContact.DetailDateTime__c == 'Face-to-face' ? 'P' : ' V';
        request.first_failed_contact_data_hour = formatDatetimeToCustomString(stakeHolderContact.FirstUnsuccessfulContactDateTime__c);
        request.first_failed_reason = stakeHolderContact.FirstUnsuccessfulContactDateTime__c != null ? stakeHolderContact.UnsuccessfulContactReason__c : null ;
        request.second_failed_contact_data_hour = formatDatetimeToCustomString(stakeHolderContact.SecondUnsuccessfulContactDateTime__c);
        request.second_failed_reason = stakeHolderContact.SecondUnsuccessfulContactDateTime__c != null  ? stakeHolderContact.UnsuccessfulContactReason__c : null ;
        request.third_failed_contact_data_hour = stakeHolderContact.ThirdUnsuccessfulContactDateTime__c != null ?formatDatetimeToCustomString(stakeHolderContact.ThirdUnsuccessfulContactDateTime__c)  : null;
        request.third_failed_reason = stakeHolderContact.ThirdUnsuccessfulContactDateTime__c != null ? stakeHolderContact.UnsuccessfulContactReason__c : null ;
       
        request.id_intervener_service = stakeHolderContact.MKISId__c != null ? stakeHolderContact.MKISId__c : null;
        request.position_portal = 'priemer_contacto';
    
        
        Map<String, Object> cleanedRequest = removeNullValues(request);
        String bodyRequest = JSON.serialize(cleanedRequest);
        System.debug(bodyRequest);        
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint (endpointMdt.Endpoint__c);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Content-Type', 'application/json');
        req.setMethod('POST');
        req.setBody(bodyRequest);
        HttpResponse response = http.send(req);
        if (response.getStatusCode() == 200) {
            System.debug(response.getBody());
            System.debug(response.getBody().replace('primerContact', 'primer-contact'));
            responseBody responseWrapper = (responseBody) JSON.deserialize(response.getBody().replace('primer-contact', 'primerContact'), responseBody.class);
            System.debug(responseWrapper);
            System.debug(JSON.serialize(responseWrapper));

            if (stakeHolderContact.mkisId__c == null) {
                stakeHolderContact.mkisId__c = responseWrapper.info.original.primerContact.id;
                update stakeHolderContact;
            }
            
            
           
        }
        */
    }
    public class requestBody{
        public String service_number{get;set;}
        public String interlocutor{get;set;}
        public String intervener_id{get;set;}
        public String visit_data_hour{get;set;}
        public String visit_detail{get;set;}
        public String first_failed_contact_data_hour{get;set;}
        public String first_failed_reason{get;set;}
        public String second_failed_contact_data_hour{get;set;}
        public String second_failed_reason{get;set;}
        public String third_failed_contact_data_hour{get;set;}
        public String third_failed_reason{get;set;}
        public String other_failed_visit_data_hour{get;set;}
        public String other_failed_visit_reason{get;set;}
        public String id_intervener_service{get;set;}
        public String position_portal{get;set;}
    }
    public class InputWrapper {
        @InvocableVariable(label=' Id' description='Receive List of Stakeholder Contact Id')
        public String stackHolderContactId;
    }

    public class responseWrapper {
        public String message{get;set;}
    }

    /**
     * @description Removes null values from a serialized object, returning a clean map
     * @param inputObj The object to serialize and filter null values from
     * @return Map with only non-null key-value pairs
     */
    public static Map<String, Object> removeNullValues(Object inputObj) {
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(inputObj));
        Map<String, Object> cleanedMap = new Map<String, Object>();
        
        for (String key : resultMap.keySet()) {
            if (resultMap.get(key) != null) {
                cleanedMap.put(key, resultMap.get(key));
            }
        }
        return cleanedMap;
    } 
    /**
     * @description Formats a Datetime value to a custom string in yyyy-MM-dd HH:mm:ss format
     * @param dt The Datetime value to format
     * @return The formatted datetime string
     */
    public static String formatDatetimeToCustomString(Datetime dt) {
        return dt.format('yyyy-MM-dd HH:mm:ss');
    }  


    public class responseBody {
        public info info{get;set;}
    }
    public class info{
        public original original{get;set;}
    }

    public class original{
        public primerContact primerContact{get;set;}
    }

    public class primerContact {
        public string id {get;set;}
    }


    


}