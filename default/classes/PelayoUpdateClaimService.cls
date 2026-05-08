/**
 * @description       : Sends updateClaim payloads to Pelayo.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 09-03-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class PelayoUpdateClaimService {

    private static final String PELAYO_ACCOUNT_CODE = 'PLYO';
    private static final String CONFIG_LABEL_PELAYO_UPDATE_CLAIM = 'Update Pelayo Claim';
    private static final String CONFIG_LABEL_PELAYO_UPDATE_ASSIGNMENT = 'Update Pelayo Assignment';
    private static final String UPDATE_CLAIM_PATH = '/updateClaim';

    /**
     * @description Enqueues a Queueable job to send updateClaim payloads for the given Case Ids.
     * @param caseIds Set of Case Ids to process.
     */
    public static void enqueue(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return;
        }
        System.enqueueJob(new UpdateClaimQueueable(new List<Id>(caseIds)));
    }

    /**
     * @description Synchronously sends updateClaim payloads to Pelayo for the given Case Ids, updating each Case with the integration result.
     * @param caseIds Set of Case Ids to process.
     */
    @TestVisible
    static void callUpdateClaimSync(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return;
        }

        Map<Id, Case> casesById = new Map<Id, Case>([
            SELECT Id, GrandAccount__c
            FROM Case
            WHERE Id IN :caseIds
        ]);

        Set<Id> pelayoCaseIds = new Set<Id>();
        for (Id caseId : casesById.keySet()) {
            Case c = casesById.get(caseId);
            if (c == null) continue;
            if (c.GrandAccount__c != PELAYO_ACCOUNT_CODE) continue;
            pelayoCaseIds.add(caseId);
        }
        if (pelayoCaseIds.isEmpty()) {
            return;
        }

        String token = PelayoWebServiceController.getToken();
        if (String.isBlank(token)) {
            updateCasesWithFailure(pelayoCaseIds, 'Failed to obtain access token for Pelayo updateClaim service.');
            return;
        }

        String endpoint = resolveUpdateClaimEndpoint();
        if (String.isBlank(endpoint)) {
            updateCasesWithFailure(pelayoCaseIds, 'Missing endpoint configuration for Pelayo updateClaim service.');
            return;
        }

        Map<Id, String> payloadByCaseId = PelayoUpdateClaimOutBoundStructure.createJSONFromCases(pelayoCaseIds);

        List<Case> casesToUpdate = new List<Case>();
        for (Id caseId : pelayoCaseIds) {
            String requestBody = payloadByCaseId.get(caseId);
            PelayoUpdateClaimOutBoundStructure.UpdateClaimResponse resp = callUpdateClaimService(endpoint, token, requestBody);

            Case cUpd = new Case(Id = caseId);
            cUpd.LastIntegrationDateTime__c = System.now();
            cUpd.LastIntegrationDescription__c = resp != null ? resp.message : 'Unknown response from updateClaim.';
            cUpd.LastIntegration__c = (resp != null && resp.success == true)
                ? ''
                : buildReprocessRoute(caseId);
            casesToUpdate.add(cUpd);

            // Best-effort user feedback (platform event), same pattern as updateAssignment.
            try {
                PelayoWebServiceController.sendResponseEvent(resp != null && resp.success == true, (String)caseId, resp != null ? resp.message : null);
            } catch (Exception e) {
                // Ignore event publish errors; do not fail integration.
            }
        }

        if (!casesToUpdate.isEmpty()) {
            PelayoUpdateClaimTriggerLogic.bypassExternalActions = true;
            update casesToUpdate;
        }
    }

    /**
     * @description Stamps a failure message and reprocess route on each Case when the integration cannot proceed.
     * @param caseIds Set of Case Ids to mark as failed.
     * @param message The failure description to store.
     */
    private static void updateCasesWithFailure(Set<Id> caseIds, String message) {
        if (caseIds == null || caseIds.isEmpty()) return;
        List<Case> casesToUpdate = new List<Case>();
        for (Id caseId : caseIds) {
            casesToUpdate.add(new Case(
                Id = caseId,
                LastIntegrationDateTime__c = System.now(),
                LastIntegrationDescription__c = message,
                LastIntegration__c = buildReprocessRoute(caseId)
            ));
        }
        if (!casesToUpdate.isEmpty()) {
            PelayoUpdateClaimTriggerLogic.bypassExternalActions = true;
            update casesToUpdate;
        }
    }

    /**
     * @description Builds the reprocess route string used by IntegrationsReprocessingBatch for a given Case.
     * @param caseId The Case Id.
     * @return Reprocess route in the format Class/Method/paramName/paramValue.
     */
    private static String buildReprocessRoute(Id caseId) {
        // Format expected by IntegrationsReprocessingBatch: Class/Method/paramName/paramValue
        return 'IntegrationsExtensionClass/updateClaimPelayoService/caseId/' + String.valueOf(caseId);
    }

    /**
     * @description Resolves the updateClaim endpoint URL from WebServiceUtils__mdt, with a fallback to the assignment config.
     * @return The normalized endpoint URL, or null if unavailable.
     */
    private static String resolveUpdateClaimEndpoint() {
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;

        WebServiceUtils__mdt config;
        try {
            config = [
                SELECT Endpoint__c
                FROM WebServiceUtils__mdt
                WHERE MasterLabel = :CONFIG_LABEL_PELAYO_UPDATE_CLAIM
                AND isSandbox__c = :isSandbox
                LIMIT 1
            ];
        } catch (Exception e) {
            // Fallback: reuse assignment endpoint config if update-claim record doesn't exist yet.
            try {
                config = [
                    SELECT Endpoint__c
                    FROM WebServiceUtils__mdt
                    WHERE MasterLabel = :CONFIG_LABEL_PELAYO_UPDATE_ASSIGNMENT
                    AND isSandbox__c = :isSandbox
                    LIMIT 1
                ];
            } catch (Exception ignored) {
                config = null;
            }
        }

        String base = config != null ? config.Endpoint__c : null;
        if (String.isBlank(base)) {
            return null;
        }

        String endpoint = base;

        // Ensure it ends with /updateClaim
        if (base.endsWith(UPDATE_CLAIM_PATH)) {
            endpoint = base;
        } else if (base.endsWith('/')) {
            endpoint = base.left(base.length() - 1) + UPDATE_CLAIM_PATH;
        } else {
            // If config already points to a specific operation, replace last path segment.
            Integer lastSlash = base.lastIndexOf('/');
            if (lastSlash > 8) {
                String lastSegment = base.substring(lastSlash);
                if (lastSegment.toLowerCase().contains('update')) {
                    endpoint = base.substring(0, lastSlash) + UPDATE_CLAIM_PATH;
                } else {
                    endpoint = base + UPDATE_CLAIM_PATH;
                }
            } else {
                endpoint = base + UPDATE_CLAIM_PATH;
            }
        }

        return PelayoWebServiceController.normalizePelayoEndpoint(endpoint);
    }

    /**
     * @description Performs the HTTP PUT call to the Pelayo updateClaim endpoint and returns the deserialized response.
     * @param endpoint The target endpoint URL.
     * @param token The authorization token.
     * @param requestBody The JSON request body.
     * @return UpdateClaimResponse with success/failure details.
     */
    private static PelayoUpdateClaimOutBoundStructure.UpdateClaimResponse callUpdateClaimService(String endpoint, String token, String requestBody) {
        PelayoUpdateClaimOutBoundStructure.UpdateClaimResponse serviceResponse = new PelayoUpdateClaimOutBoundStructure.UpdateClaimResponse();
        try {
            HttpRequest request = HttpRequestFactory.createHttpRequest(
                'PUT',
                endpoint,
                new Map<String, String>{
                    'Accept' => 'application/json',
                    'Content-Type' => 'application/json',
                    'Authorization' => token
                },
                requestBody
            );

            Http http = new Http();
            HttpResponse response = http.send(request);
            System.debug(response.getBody());
            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                serviceResponse = (PelayoUpdateClaimOutBoundStructure.UpdateClaimResponse) JSON.deserialize(
                    response.getBody(),
                    PelayoUpdateClaimOutBoundStructure.UpdateClaimResponse.class
                );
            } else {
                serviceResponse.success = false;
                serviceResponse.message = 'Failed to update claim in Pelayo service. Status Code: ' + response.getStatusCode();
                serviceResponse.errors = response.getBody();
            }
        } catch (Exception e) {
            serviceResponse.success = false;
            serviceResponse.message = 'Exception while calling Pelayo updateClaim service: ' + e.getMessage();
        }
        return serviceResponse;
    }

    public class UpdateClaimQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> caseIds;

        public UpdateClaimQueueable(List<Id> caseIds) {
            this.caseIds = caseIds;
        }

        public void execute(QueueableContext context) {
            // Avoid unexpected failures in tests unless explicitly enabled.
            if (Test.isRunningTest() && !PelayoUpdateClaimTriggerLogic.enableCalloutsInTests) {
                return;
            }
            callUpdateClaimSync(new Set<Id>(caseIds));
        }
    }
}