/**
 * @description       : Handles Create and Update Intervention calls to MKIS ELBA API.
 *                      Triggered from Service__c insert (Create) and Service__c update (Update).
 *                      Interventions in MKIS correspond to Service__c records in Salesforce.
 * @author            : Daniel Flores
 * @group             : MKIS Integration
 * @last modified on  : 06-05-2026
 * @last modified by  : Daniel Flores
**/
public without sharing class MKISElbaInterventionHandler {

    private static final String ENDPOINT_INTERVENTIONS = '/interventions';

    private static Map<String, String> stateMapping {
        get {
            if (stateMapping == null) {
                stateMapping = new Map<String, String>();
                for (MKISInterventionStateMapping__mdt m : [
                    SELECT SalesforceStatus__c, MKISCode__c
                    FROM MKISInterventionStateMapping__mdt
                ]) {
                    stateMapping.put(m.SalesforceStatus__c, m.MKISCode__c);
                }
            }
            return stateMapping;
        }
        set;
    }

    /**
    * @description Creates interventions in MKIS ELBA for all Service__c records related to the given Orders
    *              that do not yet have a MKISId__c. Intended to be called from a @future context.
    * @param orderIds List of Order Ids whose Services should be created in MKIS
    **/
    /**
    * @description Creates interventions in MKIS ELBA for all Service__c records related to the given Orders
    *              that do not yet have a MKISId__c.
    * @param orderIds List of Order Ids whose Services should be created in MKIS
    **/
    public static void createInterventionsForOrders(List<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) return;
        List<Service__c> services = [
            SELECT Id, Order__c, Stakeholder__c,
                   Type__c, StartDate__c, Status__c, MKISId__c,
                   Order__r.Urgent__c, Order__r.UrlLinkStatus__c, Situation__c
            FROM Service__c
            WHERE Order__c IN :orderIds
              AND MKISId__c = null AND STATUS__C != 'Cancelado/Anulado'
        ];
        List<Service__c> servicesToUpdate = new List<Service__c>();
        for (Service__c svc : services) {
            if (hasOrderRelation(svc)) {
                String mkisId = createIntervention(svc);
                if (String.isNotBlank(mkisId)) {
                    servicesToUpdate.add(new Service__c(
                        Id = svc.Id,
                        MKISId__c = mkisId,
                        LastIntegrationDateTime__c = System.now(),
                        LastIntegration__c = 'MKISElbaInterventionHandler/createIntervention',
                        LastIntegrationDescription__c = 'Success'
                    ));
                }
            }
        }
        if (!servicesToUpdate.isEmpty()) {
            update servicesToUpdate;
        }
    }

    /**
    * @description Async entry point: creates interventions in MKIS for all Service__c records
    *              related to the given Orders that have no MKISId__c yet.
    * @param orderIds List of Order Ids
    **/
    @future(callout=true)
    public static void createInterventionsForOrdersAsync(List<Id> orderIds) {
        createInterventionsForOrders(orderIds);
    }

    /**
    * @description Creates an intervention in MKIS ELBA when a Service__c is inserted.
    * @param serviceIds List of Service__c Ids to process
    **/
    @future(callout=true)
    public static void createInterventionAsync(List<Id> serviceIds) {
        List<Service__c> services = queryServices(serviceIds);
        List<Service__c> servicesToUpdate = new List<Service__c>();
        for (Service__c svc : services) {
            if (hasOrderRelation(svc)) {
                String mkisId = createIntervention(svc);
                if (String.isNotBlank(mkisId)) {
                    servicesToUpdate.add(new Service__c(
                        Id = svc.Id,
                        MKISId__c = mkisId,
                        LastIntegrationDateTime__c = System.now(),
                        LastIntegration__c = 'MKISElbaInterventionHandler/createIntervention',
                        LastIntegrationDescription__c = 'Success'
                    ));
                }
            }
        }
        if (!servicesToUpdate.isEmpty()) {
            update servicesToUpdate;
        }
    }

    /**
    * @description Creates an intervention in MKIS ELBA for a single Service__c.
    * @param svc The Service__c record
    * @return The MKIS intervention id from response, or null on failure
    **/
    public static String createIntervention(Service__c svc) {
        if (!hasOrderRelation(svc)) {
            return null;
        }

        MKISElbaStructures.CreateInterventionRequest req = buildCreateInterventionRequest(svc);
        String body = JSON.serialize(req, true);
        System.debug(body);
        try {
            HttpResponse res = MKISElbaCalloutService.doPost(ENDPOINT_INTERVENTIONS, body);
            System.debug('MKIS Create Intervention response: ' + res.getStatusCode() + ' - ' + res.getBody());
            Boolean success = res.getStatusCode() == 200;
            String message = parseApiMessage(res.getBody());
            sendResponseEvent(svc.Order__c, success, message);
            if (success) {
                return parseMkisId(res.getBody());
            }
        } catch (Exception e) {
            System.debug('MKIS Create Intervention error: ' + e.getMessage());
            sendResponseEvent(svc.Order__c, false, e.getMessage());
        }
        return null;
    }

    /**
    * @description Updates an intervention in MKIS ELBA when a Service__c is updated.
    * @param serviceIds List of Service__c Ids to process
    **/
    @future(callout=true)
    public static void updateInterventionAsync(List<Id> serviceIds) {
        List<Service__c> services = queryServices(serviceIds);
        for (Service__c svc : services) {
            if (hasOrderRelation(svc) && String.isNotBlank(svc.MKISId__c)) {
                updateIntervention(svc);
            }
        }
    }

    /**
    * @description Updates an intervention in MKIS ELBA for a single Service__c.
    * @param svc The Service__c record
    **/
    public static void updateIntervention(Service__c svc) {
        if (!hasOrderRelation(svc) || String.isBlank(svc.MKISId__c)) {
            return;
        }

        MKISElbaStructures.UpdateInterventionRequest req = buildUpdateInterventionRequest(svc);
        String body = JSON.serialize(req, true);

        try {
            HttpResponse res = MKISElbaCalloutService.doPut(ENDPOINT_INTERVENTIONS + '/' + svc.MKISId__c, body);
            System.debug('MKIS Update Intervention response: ' + res.getStatusCode() + ' - ' + res.getBody());
            sendResponseEvent(svc.Order__c, res.getStatusCode() == 200, parseApiMessage(res.getBody()));
        } catch (Exception e) {
            System.debug('MKIS Update Intervention error: ' + e.getMessage());
            sendResponseEvent(svc.Order__c, false, e.getMessage());
        }
    }

    /**
    * @description Builds the Create Intervention request from a Service__c record.
    * @param svc The Service__c record
    * @return CreateInterventionRequest populated from Service__c fields
    **/
    private static MKISElbaStructures.CreateInterventionRequest buildCreateInterventionRequest(Service__c svc) {
        MKISElbaStructures.CreateInterventionRequest req = new MKISElbaStructures.CreateInterventionRequest();
        req.order_id = String.valueOf(svc.Order__c);
        req.stakeholder_external_id = svc.Stakeholder__c != null ? String.valueOf(svc.Stakeholder__c) : null;
        req.category = svc.Type__c;
        req.start_date = svc.StartDate__c != null ? String.valueOf(svc.StartDate__c) : null;
        req.urgent = (svc.Order__r != null && svc.Order__r.Urgent__c == true) ? 1 : 0;
        req.external_id = String.valueOf(svc.Id);
        req.situation_type = svc.Situation__c;
        req.state = mapState(svc.Status__c);
        return req;
    }

    /**
    * @description Builds the Update Intervention request from a Service__c record.
    * @param svc The Service__c record
    * @return UpdateInterventionRequest populated from Service__c fields
    **/
    private static MKISElbaStructures.UpdateInterventionRequest buildUpdateInterventionRequest(Service__c svc) {
        MKISElbaStructures.UpdateInterventionRequest req = new MKISElbaStructures.UpdateInterventionRequest();
        req.stakeholder_id = svc.Stakeholder__r != null ? svc.Stakeholder__r.MKISId__c : null;
        req.category = svc.Type__c;
        req.start_date = svc.StartDate__c != null ? String.valueOf(svc.StartDate__c) : null;
        req.urgent = (svc.Order__r != null && svc.Order__r.Urgent__c == true) ? 1 : 0;
        req.situation_type = svc.Situation__c;
        req.state = mapState(svc.Status__c);

        return req;
    }

    /**
    * @description Maps a Salesforce Service__c Status__c value to its MKIS code
    *              using the MKISInterventionStateMapping__mdt custom metadata.
    * @param sfStatus The Salesforce picklist value
    * @return The MKIS state code, or the original value if no mapping found
    **/
    @TestVisible
    private static String mapState(String sfStatus) {
        if (String.isBlank(sfStatus)) return null;
        String mapped = stateMapping.get(sfStatus);
        return mapped != null ? mapped : sfStatus;
    }

    /**
    * @description Queries Service__c records with all fields needed for MKIS integration.
    * @param serviceIds List of Service__c Ids to query
    * @return List of Service__c records
    **/
    public static List<Service__c> queryServices(List<Id> serviceIds) {
        return [
            SELECT Id, Order__c, Stakeholder__c, Stakeholder__r.MKISId__c,
                   Type__c, StartDate__c, Status__c, MKISId__c,
                   Order__r.Urgent__c, Order__r.UrlLinkStatus__c, Situation__c
            FROM Service__c
            WHERE Id IN :serviceIds
        ];
    }

    /**
    * @description Determines whether a Service__c has a related Order.
    * @param svc The Service__c record
    * @return Boolean true if Order__c is populated
    **/
    private static Boolean hasOrderRelation(Service__c svc) {
        return svc != null && svc.Order__c != null;
    }

    /**
    * @description Parses the MKIS id from the API CREATE response (data.id).
    * @param responseBody The raw HTTP response body
    * @return The extracted id string, or null if not found
    **/
    private static String parseMkisId(String responseBody) {
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            Object dataObj = parsed.get('data');
            if (dataObj instanceof Map<String, Object>) {
                Object idVal = ((Map<String, Object>) dataObj).get('id');
                if (idVal != null) return String.valueOf(idVal);
            }
        } catch (Exception e) {
            // Fall through
        }
        return null;
    }

    /**
    * @description Parses the API JSON response body to extract the message field.
    * @param responseBody The raw HTTP response body
    * @return The extracted message string, or the raw body if parsing fails
    **/
    private static String parseApiMessage(String responseBody) {
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            if (parsed.containsKey('message')) {
                return (String) parsed.get('message');
            }
        } catch (Exception e) {
            // Fall through
        }
        return responseBody;
    }

    /**
    * @description Publishes a PopUP_Service__e platform event with the integration result.
    * @param serviceId The Service__c record Id
    * @param isSuccess Whether the API call was successful
    * @param message The response message
    **/
    private static void sendResponseEvent(Id serviceId, Boolean isSuccess, String message) {
        PopUP_Service__e responseEvent = new PopUP_Service__e(
            RecordId__c = String.valueOf(serviceId),
            Message__c = message,
            Success__c = isSuccess
        );
        EventBus.publish(responseEvent);
    }
}