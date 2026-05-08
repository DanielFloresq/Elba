/**
 * @description       : Handles Create and Update Incidence calls to MKIS ELBA API.
 *                      Triggered from Incident insert (Create) and Incident update (Update).
 * @author            : Daniel Flores
 * @group             : MKIS Integration
 * @last modified on  : 06-05-2026
 * @last modified by  : Daniel Flores
**/
public without sharing class MKISElbaIncidenceHandler {

    private static final String ENDPOINT_INCIDENCES = '/incidences';

    /**
    * @description Creates an incidence in MKIS ELBA when an Incident is created.
    * @param incidentIds List of Incident Ids to process
    **/
    @future(callout=true)
    public static void createIncidenceAsync(List<Id> incidentIds) {
        List<Incident> incidents = queryIncidents(incidentIds);
        for (Incident inc : incidents) {
            if (hasOrderRelation(inc)) {
                createIncidence(inc);
            }
        }
    }

    /**
    * @description Creates an incidence in MKIS ELBA for a single Incident.
    **/
    public static void createIncidence(Incident inc) {
        if (!hasOrderRelation(inc)) {
            return;
        }

        MKISElbaStructures.CreateIncidenceRequest req = buildCreateIncidenceRequest(inc);
        String body = JSON.serialize(req, true);
        System.debug(body);
        try {
            HttpResponse res = MKISElbaCalloutService.doPost(ENDPOINT_INCIDENCES, body);
            System.debug('MKIS Create Incidence response: ' + res.getStatusCode() + ' - ' + res.getBody());
            sendResponseEvent(inc.Id, res.getStatusCode() == 200, parseApiMessage(res.getBody()));
        } catch (Exception e) {
            System.debug('MKIS Create Incidence error: ' + e.getMessage());
            sendResponseEvent(inc.Id, false, e.getMessage());
        }
    }

    /**
    * @description Updates an incidence in MKIS ELBA when an Incident is updated.
    * @param incidentIds List of Incident Ids to process
    **/
    @future(callout=true)
    public static void updateIncidenceAsync(List<Id> incidentIds) {
        List<Incident> incidents = queryIncidents(incidentIds);
        for (Incident inc : incidents) {
            if (hasOrderRelation(inc)) {
                updateIncidence(inc);
            }
        }
    }

    /**
    * @description Updates an incidence in MKIS ELBA for a single Incident.
    **/
    public static void updateIncidence(Incident inc) {
        if (!hasOrderRelation(inc)) {
            return;
        }

        MKISElbaStructures.UpdateIncidenceRequest req = buildUpdateIncidenceRequest(inc);
        String body = JSON.serialize(req, true);

        try {
            // PUT /api/incidences/{id} - using ExternalId__c as the MKIS identifier
            String externalId = inc.ExternalId__c != null ? inc.ExternalId__c : String.valueOf(inc.Id);
            HttpResponse res = MKISElbaCalloutService.doPut(ENDPOINT_INCIDENCES + '/' + externalId, body);
            System.debug('MKIS Update Incidence response: ' + res.getStatusCode() + ' - ' + res.getBody());
            sendResponseEvent(inc.Id, res.getStatusCode() == 200, parseApiMessage(res.getBody()));
        } catch (Exception e) {
            System.debug('MKIS Update Incidence error: ' + e.getMessage());
            sendResponseEvent(inc.Id, false, e.getMessage());
        }
    }

    /**
    * @description Builds the Create Incidence request from an Incident record.
    * TODO: Ajustar mapeamentos conforme definido pelo utilizador.
    **/
    private static MKISElbaStructures.CreateIncidenceRequest buildCreateIncidenceRequest(Incident inc) {
        MKISElbaStructures.CreateIncidenceRequest req = new MKISElbaStructures.CreateIncidenceRequest();

        req.order_id                  = inc.OrderService__c;
        req.incidence_type            = inc.Type;
        req.incidence_motive          = inc.Reason__c;
        req.incidence_submotive       = inc.Sub_Reason__c;
        req.internal_process          = null; 
        req.incidence_management_team = inc.ManagementTeam__c;
        req.responsible               = inc.ResponsibleParty__c; 
        req.description               = inc.Subject;
        req.origin                    = inc.Origin__c;
        req.incidence_result          = inc.Result__c;
        req.incidence_causer_type     = inc.ResponsiblePartyType__c;
        req.causer                    = null; 
        req.repairer                  = inc.Repairer__c;
        req.incidence_channel         = inc.Channel__c;
        req.state                     = inc.Status ;
        req.customer_disagreement     = null; // TODO: confirmar campo Salesforce
        req.opened_at                 = inc.CreatedDate != null ? String.valueOf(inc.CreatedDate) : null;
        req.opened_by                 = inc.CreatedBy != null ? inc.CreatedBy.Name : null;
        req.reopened_at               = inc.ReopenDateTime__c != null ? String.valueOf(inc.ReopenDateTime__c) : null;
        req.reopened_motive           = inc.ReopenReason__c;
        req.external_id               = String.valueOf(inc.Id);

        return req;
    }

    /**
    * @description Builds the Update Incidence request from an Incident record.
    * TODO: Ajustar mapeamentos conforme definido pelo utilizador.
    **/
    private static MKISElbaStructures.UpdateIncidenceRequest buildUpdateIncidenceRequest(Incident inc) {
        MKISElbaStructures.UpdateIncidenceRequest req = new MKISElbaStructures.UpdateIncidenceRequest();

        req.incidence_type            = inc.Type;
        req.incidence_motive          = inc.Reason__c;
        req.incidence_submotive       = inc.Sub_Reason__c;
        req.internal_process          = null; // TODO: confirmar campo Salesforce
        req.incidence_management_team = inc.ManagementTeam__c;
        req.responsible               = inc.ResponsibleParty__c;
        req.description               = inc.Subject;
        req.origin                    = inc.Origin__c;
        req.incidence_result          = inc.Result__c;
        req.incidence_causer_type     = inc.ResponsiblePartyType__c;
        req.causer                    = null; // TODO: confirmar campo Salesforce
        req.repairer                  = inc.Repairer__c;
        req.incidence_channel         = inc.Channel__c;
        req.state                     = inc.Status ;
        req.customer_disagreement     = null; // TODO: confirmar campo Salesforce
        req.reopened_at               = inc.ReopenDateTime__c != null ? String.valueOf(inc.ReopenDateTime__c) : null;
        req.reopened_motive           = inc.ReopenReason__c;

        return req;
    }


    /**
    * @description Query Incidents with all fields needed for MKIS integration.
    **/
    private static List<Incident> queryIncidents(List<Id> incidentIds) {
        return [
            SELECT Id, Subject, Description, Status, Priority,
                   ExternalId__c, OrderService__c, Reason__c, Sub_Reason__c,
                   Result__c, Channel__c, Origin__c, Type,
                   NestedCaseID__c, NestedCaseID__r.CaseNumber,
                   ManagementTeam__c, Repairer__c,
                   ResponsibleParty__c, ResponsiblePartyType__c,
                   ReopenDateTime__c, ReopenReason__c,
                   CreatedDate, CreatedBy.Name
            FROM Incident
            WHERE Id IN :incidentIds
        ];
    }

    /**
    * @description Checks whether the Incident has a related Order service.
    * @param inc The Incident record
    * @return Boolean true if OrderService__c is populated
    **/
    private static Boolean hasOrderRelation(Incident inc) {
        return inc != null && inc.OrderService__c != null;
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
        }
        return responseBody;
    }

    /**
    * @description Publishes a PopUP_Service__e platform event with the integration result.
    * @param incidentId The Incident record Id
    * @param isSuccess Whether the API call was successful
    * @param message The response message
    **/
    private static void sendResponseEvent(Id incidentId, Boolean isSuccess, String message) {
        PopUP_Service__e responseEvent = new PopUP_Service__e(
            RecordId__c = String.valueOf(incidentId),
            Message__c = message,
            Success__c = isSuccess
        );
        EventBus.publish(responseEvent);
    }
}