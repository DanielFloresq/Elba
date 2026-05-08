/**
 * @description       : Handles Create, Update and Delete Stakeholder calls to MKIS ELBA API.
 *                      Triggered from Stakeholders__c insert, update and delete.
 * @author            : Daniel Flores
 * @group             : MKIS Integration
 * @last modified on  : 06-05-2026
 * @last modified by  : Daniel Flores
**/
public without sharing class MKISElbaStakeholderHandler {

    private static final String ENDPOINT_STAKEHOLDERS = '/stakeholders';

    // ===================== ASYNC ENTRY POINTS =====================

    /**
    * @description Creates stakeholders in MKIS ELBA when Stakeholders__c records are inserted.
    * @param stakeholderIds List of Stakeholders__c Ids to process
    **/
    @future(callout=true)
    public static void createStakeholderAsync(List<Id> stakeholderIds) {
        for (Stakeholders__c s : queryStakeholders(stakeholderIds)) {
            Order ord = findRelatedOrder(s.Case__c);
            if (ord == null) continue;
            createStakeholder(s, ord.Id);
        }
    }

    /**
    * @description Updates stakeholders in MKIS ELBA when Stakeholders__c records are updated.
    * @param stakeholderIds List of Stakeholders__c Ids to process
    **/
    @future(callout=true)
    public static void updateStakeholderAsync(List<Id> stakeholderIds) {
        for (Stakeholders__c s : queryStakeholders(stakeholderIds)) {
            if (String.isBlank(s.MKISId__c)) continue;
            updateStakeholder(s);
        }
    }

    /**
    * @description Deletes stakeholders in MKIS ELBA when Stakeholders__c records are deleted.
    * @param mkisIds List of MKISId__c values from the deleted records
    **/
    @future(callout=true)
    public static void deleteStakeholderAsync(List<String> mkisIds) {
        for (String mkisId : mkisIds) {
            if (String.isBlank(mkisId)) continue;
            deleteStakeholder(mkisId);
        }
    }

    // ===================== CORE METHODS =====================

    /**
    * @description POSTs a new stakeholder to MKIS ELBA.
    * @param s The Stakeholders__c record
    * @param orderId The Salesforce Order Id linked to the same case
    **/
    private static void createStakeholder(Stakeholders__c s, Id orderId) {
        MKISElbaStructures.CreateStakeholderRequest req = buildCreateRequest(s, orderId);
        String body = JSON.serialize(req, true);

        try {
            HttpResponse res = MKISElbaCalloutService.doPost(ENDPOINT_STAKEHOLDERS, body);
            System.debug('MKIS Create Stakeholder [' + s.Id + '] response: ' + res.getStatusCode() + ' - ' + res.getBody());
            Boolean success = res.getStatusCode() == 200 || res.getStatusCode() == 201;
            sendResponseEvent(s.Id, success, parseApiMessage(res.getBody()));
            if (success) {
                String mkisId = parseMkisId(res.getBody());
                if (String.isNotBlank(mkisId)) {
                    update new Stakeholders__c(Id = s.Id, MKISId__c = mkisId);
                }
            }
        } catch (Exception e) {
            System.debug('MKIS Create Stakeholder error: ' + e.getMessage());
            sendResponseEvent(s.Id, false, e.getMessage());
        }
    }

    /**
    * @description PUTs (updates) an existing stakeholder in MKIS ELBA.
    * @param s The Stakeholders__c record (must have MKISId__c set)
    **/
    private static void updateStakeholder(Stakeholders__c s) {
        MKISElbaStructures.UpdateStakeholderRequest req = buildUpdateRequest(s);
        String body = JSON.serialize(req, true);
        String endpoint = ENDPOINT_STAKEHOLDERS + '/' + s.MKISId__c;

        try {
            HttpResponse res = MKISElbaCalloutService.doPut(endpoint, body);
            System.debug('MKIS Update Stakeholder [' + s.MKISId__c + '] response: ' + res.getStatusCode() + ' - ' + res.getBody());
            sendResponseEvent(s.Id, res.getStatusCode() == 200, parseApiMessage(res.getBody()));
        } catch (Exception e) {
            System.debug('MKIS Update Stakeholder error: ' + e.getMessage());
            sendResponseEvent(s.Id, false, e.getMessage());
        }
    }

    /**
    * @description DELETEs a stakeholder in MKIS ELBA by its MKIS id.
    * @param mkisId The MKIS stakeholder id
    **/
    private static void deleteStakeholder(String mkisId) {
        String endpoint = ENDPOINT_STAKEHOLDERS + '/' + mkisId;

        try {
            HttpResponse res = MKISElbaCalloutService.doDelete(endpoint);
            System.debug('MKIS Delete Stakeholder [' + mkisId + '] response: ' + res.getStatusCode() + ' - ' + res.getBody());
        } catch (Exception e) {
            System.debug('MKIS Delete Stakeholder error: ' + e.getMessage());
        }
    }

    // ===================== REQUEST BUILDERS =====================

    private static MKISElbaStructures.CreateStakeholderRequest buildCreateRequest(Stakeholders__c s, Id orderId) {
        MKISElbaStructures.CreateStakeholderRequest req = new MKISElbaStructures.CreateStakeholderRequest();
        req.order_id      = String.valueOf(orderId);
        req.name          = s.Name;
        req.stakeholder_type = s.StakeholderType__c;
        req.tax_number    = s.StakeholderTaxID__c;
        req.phone_number  = s.PrimaryMobile__c;
        req.address       = buildAddress(s);
        req.external_id   = String.valueOf(s.Id);
        return req;
    }

    private static MKISElbaStructures.UpdateStakeholderRequest buildUpdateRequest(Stakeholders__c s) {
        MKISElbaStructures.UpdateStakeholderRequest req = new MKISElbaStructures.UpdateStakeholderRequest();
        req.name          = s.Name;
        req.stakeholder_type = s.StakeholderType__c;
        req.tax_number    = s.StakeholderTaxID__c;
        req.phone_number  = s.PrimaryMobile__c;
        req.address       = buildAddress(s);
        req.external_id   = String.valueOf(s.Id);
        return req;
    }

    private static String buildAddress(Stakeholders__c s) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(s.Address__Street__s))     parts.add(s.Address__Street__s);
        if (String.isNotBlank(s.Address__City__s))       parts.add(s.Address__City__s);
        if (String.isNotBlank(s.Address__PostalCode__s)) parts.add(s.Address__PostalCode__s);
        return parts.isEmpty() ? null : String.join(parts, ' ');
    }

    // ===================== QUERIES =====================

    private static List<Stakeholders__c> queryStakeholders(List<Id> ids) {
        return [
            SELECT Id, Name, StakeholderType__c, StakeholderTaxID__c, PrimaryMobile__c, MKISId__c,
                   Address__Street__s, Address__City__s, Address__PostalCode__s,
                   Case__c
            FROM Stakeholders__c
            WHERE Id IN :ids
        ];
    }

    /**
    * @description Finds the Order related to a Case that has already been sent to MKIS (UrlLinkStatus__c = true).
    * @param caseId The Case Id
    * @return The matching Order, or null if not found
    **/
    private static Order findRelatedOrder(Id caseId) {
        if (caseId == null) return null;
        List<Order> orders = [
            SELECT Id
            FROM Order
            WHERE CaseNumber__c = :caseId
              AND UrlLinkStatus__c = true
            LIMIT 1
        ];
        return orders.isEmpty() ? null : orders[0];
    }

    // ===================== RESPONSE PARSING =====================

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

    private static String parseMkisId(String responseBody) {
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            Object dataObj = parsed.get('data');
            if (dataObj instanceof Map<String, Object>) {
                Object idVal = ((Map<String, Object>) dataObj).get('id');
                if (idVal != null) {
                    return String.valueOf(idVal);
                }
            }
        } catch (Exception e) {
            System.debug('parseMkisId error: ' + e.getMessage());
        }
        return null;
    }

    /**
    * @description Publishes a PopUP_Service__e platform event with the integration result.
    * @param recordId The Stakeholders__c record Id
    * @param isSuccess Whether the API call was successful
    * @param message The response message
    **/
    private static void sendResponseEvent(Id recordId, Boolean isSuccess, String message) {
        PopUP_Service__e responseEvent = new PopUP_Service__e(
            RecordId__c = String.valueOf(recordId),
            Message__c = message,
            Success__c = isSuccess
        );
        EventBus.publish(responseEvent);
    }
}