/**
 * @description       : Invocable action for updating the first visit date on service records via MKIS
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 18-08-2025
 * @last modified by  : Daniel Flores
**/
public with sharing class UpdateServiceFirstVisit {

    /**
     * @description Invocable method that triggers the first visit update for a given Order ID.
     * @param listOrder List containing the Order ID to process (uses the first element).
     */
    @InvocableMethod(label='UPDATE SERVICE FIRST VISIT' )
    public static void UpdateServiceFirstVisit(List<String> listOrder) {
        UpdateServiceFirstVisitFuture(listOrder[0]);
    }


    /**
     * @description Future method that performs the callout to the MKIS API to update the first visit data for the specified Order.
     * @param orderId The ID of the Order record to update.
     */
    @future(callout=true)
    public static void UpdateServiceFirstVisitFuture(String orderId) {
        Order service = [SELECT Id, Date__c, ThirdPartyResponsible__c, GeoLocation__c , InitialDamagesLocated__c , Coverage__c , Description , ThirdPartyInformation__c , InitialDamagesRepaired__c ,  NoRepairReason__c , EstimatedToExceedLimit__c FROM Order WHERE Id=:orderId];

        firstVisit firstVisit = new firstVisit();
        firstVisit.order_id = service.Id;
        firstVisit.service_state_id = 'FP';
        firstVisit.first_visit_date = service.Date__c != null ? String.valueof(service.Date__c): null;
        firstVisit.cause_type = service.ThirdPartyResponsible__c;
        firstVisit.damage_origin_located = service.InitialDamagesLocated__c == 'Yes' ? 1 : 0;
        firstVisit.is_cause_third_party_repaired = service.InitialDamagesRepaired__c == 'Yes' ? 1 : 0;
       /*  firstVisit.is_damage_origin_repaired = service.NoRepairReason__c != null ? Integer.valueOf(service.NoRepairReason__c= */
        firstVisit.estimated_cost_exceeds = service.EstimatedToExceedLimit__c == 'Yes' ? 1 : 0;
        firstVisit.visit_description = service.Description;  
        firstVisit.coverage_name = service.Coverage__c;
        firstVisit.non_repair_reason_name = service.NoRepairReason__c;
        
        String token = WebServicesUtilities.login();
        Organization org = [SELECT IsSandbox FROM Organization];
        WebServiceUtils__mdt endpointMdt = [SELECT Endpoint__c FROM WebServiceUtils__mdt WHERE Label = 'Create New Service' AND IsSandbox__c  = :org.IsSandbox LIMIT 1 ];

        String bodyRequest = JSON.serialize(firstVisit);          

        System.debug(bodyRequest);
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint (endpointMdt.Endpoint__c);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Content-Type', 'application/json');
        req.setMethod('PUT');
        req.setBody(bodyRequest);
        
        HttpResponse response = http.send(req);

        System.debug(response.getBody());

       
        String responseBody = response.getBody();

       
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

        
        String apiMessage = (String) resultMap.get('message');

        if (apiMessage != null) {
            service.LastIntegrationDescription__c = apiMessage;
            service.LastIntegrationDateTime__c = System.now();
            update service;
        }


    }



    

    public class firstVisit{
        public String order_id;
        public String service_state_id;
        public String first_visit_date;
        public String cause_type;
        public Integer damage_origin_located;
        public Integer is_cause_third_party_repaired;
        public Integer is_damage_origin_repaired;
        public Integer estimated_cost_exceeds;
        public String visit_description;
        public String non_repair_reason_name;
        public String coverage_name;
        public String failed_visit_date;
        public String failed_visit_reason_name;
    }
}