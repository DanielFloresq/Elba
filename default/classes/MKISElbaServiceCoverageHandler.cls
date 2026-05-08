/**
 * @description       : Handles Create Service Coverage calls to MKIS ELBA API.
 *                      Triggered from InsurableCoverage__c insert.
 *                      Service Coverages in MKIS correspond to InsurableCoverage__c records in Salesforce.
 * @author            : Daniel Flores
 * @group             : MKIS Integration
 * @last modified on  : 04-05-2026
 * @last modified by  : Daniel Flores
**/
public without sharing class MKISElbaServiceCoverageHandler {

    private static final String ENDPOINT_SERVICE_COVERAGES = '/service-coverages';

    /**
    * @description Creates service coverages in MKIS ELBA when InsurableCoverage__c records are inserted.
    * @param coverageIds List of InsurableCoverage__c Ids to process
    **/
    @future(callout=true)
    public static void createServiceCoverageAsync(List<Id> coverageIds) {
        List<InsurableCoverage__c> coverages = queryInsurableCoverages(coverageIds);
        List<InsurableCoverage__c> coveragesToUpdate = new List<InsurableCoverage__c>();
        for (InsurableCoverage__c cov : coverages) {
            if (hasCaseRelation(cov)) {
                String mkisId = createServiceCoverage(cov);
                if (String.isNotBlank(mkisId)) {
                    coveragesToUpdate.add(new InsurableCoverage__c(
                        Id = cov.Id,
                        ExternalKey__c = mkisId
                    ));
                }
            }
        }
        if (!coveragesToUpdate.isEmpty()) {
            update coveragesToUpdate;
        }
    }

    /**
    * @description Creates a service coverage in MKIS ELBA for a single InsurableCoverage__c.
    * @param cov The InsurableCoverage__c record
    * @return The MKIS service coverage id from response, or null on failure
    **/
    public static String createServiceCoverage(InsurableCoverage__c cov) {
        if (!hasCaseRelation(cov)) {
            return null;
        }

        MKISElbaStructures.CreateServiceCoverageRequest req = buildCreateServiceCoverageRequest(cov);
        String body = JSON.serialize(req, true);

        try {
            HttpResponse res = MKISElbaCalloutService.doPost(ENDPOINT_SERVICE_COVERAGES, body);
            System.debug('MKIS Create Service Coverage response: ' + res.getStatusCode() + ' - ' + res.getBody());
            Boolean success = res.getStatusCode() == 200;
            String message = parseApiMessage(res.getBody());
            sendResponseEvent(cov.Id, success, message);
            if (success) {
                return parseMkisId(res.getBody());
            }
        } catch (Exception e) {
            System.debug('MKIS Create Service Coverage error: ' + e.getMessage());
            sendResponseEvent(cov.Id, false, e.getMessage());
        }
        return null;
    }

    /**
    * @description Builds the Create Service Coverage request from an InsurableCoverage__c record.
    * @param cov The InsurableCoverage__c record
    * @return CreateServiceCoverageRequest populated from InsurableCoverage__c fields
    **/
    private static MKISElbaStructures.CreateServiceCoverageRequest buildCreateServiceCoverageRequest(InsurableCoverage__c cov) {
        MKISElbaStructures.CreateServiceCoverageRequest req = new MKISElbaStructures.CreateServiceCoverageRequest();
        req.case_id = String.valueOf(cov.Claim__c);
        req.coverage = cov.Coverage__c;
        req.limit_amount = cov.CoverageAmountLimit__c;
        req.deductible_amount = cov.DeductibleAmount__c;
        req.external_id = String.valueOf(cov.Id);
        return req;
    }

    /**
    * @description Queries InsurableCoverage__c records with all fields needed for MKIS integration.
    * @param coverageIds List of InsurableCoverage__c Ids to query
    * @return List of InsurableCoverage__c records
    **/
    private static List<InsurableCoverage__c> queryInsurableCoverages(List<Id> coverageIds) {
        return [
            SELECT Id, Claim__c, Coverage__c, CoverageAmountLimit__c, DeductibleAmount__c
            FROM InsurableCoverage__c
            WHERE Id IN :coverageIds
        ];
    }

    /**
    * @description Determines whether an InsurableCoverage__c has a related Case (Claim).
    * @param cov The InsurableCoverage__c record
    * @return Boolean true if Claim__c is populated
    **/
    private static Boolean hasCaseRelation(InsurableCoverage__c cov) {
        return cov != null && cov.Claim__c != null;
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
    * @param coverageId The InsurableCoverage__c record Id
    * @param isSuccess Whether the API call was successful
    * @param message The response message
    **/
    private static void sendResponseEvent(Id coverageId, Boolean isSuccess, String message) {
        PopUP_Service__e responseEvent = new PopUP_Service__e(
            RecordId__c = String.valueOf(coverageId),
            Message__c = message,
            Success__c = isSuccess
        );
        EventBus.publish(responseEvent);
    }
}