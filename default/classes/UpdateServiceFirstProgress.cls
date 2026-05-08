/**
 * @description       : Invocable action for updating the first progress date on service records via MKIS
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 29-04-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class UpdateServiceFirstProgress {

    /**
     * @description Invocable method that triggers the first progress update for a given Order ID.
     * @param listOrder List containing the Order ID to process (uses the first element).
     */
    @InvocableMethod(label='UPDATE SERVICE FIRST PROGRESS' )
    public static void UpdateServiceFirstProgress(List<String> listOrder) {
        UpdateServiceFirstProgressFuture(listOrder[0]);
    }


    /**
     * @description Future method that performs the callout to the MKIS API to update the first progress data for the specified Order.
     * @param orderId The ID of the Order record to update.
     */
    @future(callout=true)
    public static void UpdateServiceFirstProgressFuture(String orderId) {
        Order service = [SELECT /* Causa__c, SubCausa__c, Origenlocalizado__c, Origendelosdanos__c, Causareparada__c , Elcausanteesuntercero__c , Reparadoorigendelosdanos__c ,Danosapreciadoscausados__c,  Intervencionreparacionrealizada__c, Observaciones__c ,  Continente__c , Sospechafraude__c ,  Contenido__c , Solicituddeintervencionperito__c , Esteticos__c, Joyas__c */  Id FROM Order WHERE Id=:orderId];

        firstProgress firstProgress = new firstProgress();
       /*  firstProgress.order_id = service.Id;
        firstProgress.service_state_id = 'B';
        firstProgress.cause_name = service.Causa__c;
        firstProgress.subcause_name = service.SubCausa__c;
        firstProgress.origin_located = service.Reparadoorigendelosdanos__c;
        firstProgress.observed_damages = service.Danosapreciadoscausados__c;
        firstProgress.first_progress_observations = service.Observaciones__c;
        firstProgress.provision_building = service.Continente__c;
        firstProgress.provision_contents = service.Contenido__c;
        firstProgress.provision_aesthetic  = service.Esteticos__c;
        firstProgress.suspected_fraud = service.Sospechafraude__c;
        firstProgress.provision_jewelry = service.Joyas__c;
        firstProgress.expert_intervention_requested = service.Solicituddeintervencionperito__c;
        
        */
        
        
        
        String token = WebServicesUtilities.login();
        Organization org = [SELECT IsSandbox FROM Organization];
        WebServiceUtils__mdt endpointMdt = [SELECT Endpoint__c FROM WebServiceUtils__mdt WHERE Label = 'Create New Service' AND IsSandbox__c  = :org.IsSandbox LIMIT 1 ];

        String bodyRequest = JSON.serialize(firstProgress);          

        System.debug(bodyRequest);
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint (endpointMdt.Endpoint__c);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Content-Type', 'application/json');
        req.setMethod('PUT');
        req.setBody(bodyRequest);
        
        HttpResponse response = http.send(req);

        String responseBody = response.getBody();

       
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

        
        String apiMessage = (String) resultMap.get('message');

     /*    if (apiMessage != null) {
            service.LastIntegrationDescription__c = apiMessage;
            service.LastIntegrationDateTime__c = System.now();
            update service;
        } */


    }



    

    public class firstProgress{
        public String order_id;
        public String service_state_id;
        public String cause_name;
        public String subcause_name;
        public String origin_located;
        public String damage_origin;
        public String cause_repaired;
        /* public String damage_origin_repaired; */
        public String observed_damages;
        public String first_progress_observations;
        public Decimal provision_building;
        public Decimal provision_contents;
        public Decimal provision_aesthetic;
        public Decimal provision_jewelry;
        public String suspected_fraud;
        public String expert_intervention_requested;
    }
}