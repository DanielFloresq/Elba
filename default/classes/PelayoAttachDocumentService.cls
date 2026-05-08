/**
 * @description       : Sends attachDocument payloads to Pelayo.
 *                      One HTTP call is made per document — if four files are provided,
 *                      four sequential POST requests are sent to the /attachDocument endpoint.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 02-04-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class PelayoAttachDocumentService {

    private static final String PELAYO_ACCOUNT_CODE         = 'PLYO';
    private static final String CONFIG_LABEL_PELAYO_UPDATE_CLAIM = 'Update Pelayo Claim';
    private static final String CONFIG_LABEL_PELAYO_UPDATE_ASSIGNMENT = 'Update Pelayo Assignment';
    private static final String ATTACH_DOCUMENT_PATH        = '/attachDocument';

    @TestVisible
    static Boolean enableCalloutsInTests = false;

    // ─── Public entry points ──────────────────────────────────────────────────

    /**
     * @description Enqueues the attachDocument callouts asynchronously.
     * @author Daniel Flores | 16-03-2026
     * @param caseId    Case (siniestro) to which the documents belong
     * @param orderId   Order (encargo) — may be null
     * @param inputs    List of FileAttachmentInput DTOs (one per file)
     **/
    public static void enqueue(
        Id caseId,
        Id orderId,
        List<PelayoAttachDocumentOutBoundStructure.FileAttachmentInput> inputs
    ) {
        if (caseId == null || inputs == null || inputs.isEmpty()) {
            return;
        }
        System.enqueueJob(new AttachDocumentQueueable(caseId, orderId, inputs));
    }

    /**
     * @description Executes the attachDocument callouts synchronously.
     *              Iterates over every FileAttachmentInput and makes one HTTP POST per file.
     * @author Daniel Flores | 16-03-2026
     * @param caseId
     * @param orderId
     * @param inputs
     **/
    @TestVisible
    static void callAttachDocumentsSync(
        Id caseId,
        Id orderId,
        List<PelayoAttachDocumentOutBoundStructure.FileAttachmentInput> inputs
    ) {
        if (caseId == null || inputs == null || inputs.isEmpty()) {
            return;
        }

        // Guard: only process Pelayo cases
        List<Case> cases = [SELECT Id, GrandAccount__c FROM Case WHERE Id = :caseId LIMIT 1];
        if (cases.isEmpty() || cases[0].GrandAccount__c != PELAYO_ACCOUNT_CODE) {
            return;
        }

        String token = PelayoWebServiceController.getToken();
        if (String.isBlank(token)) {
            // Log failure and exit — no record to update in this scenario
            System.debug(LoggingLevel.ERROR,
                'PelayoAttachDocumentService: failed to obtain access token.');
            return;
        }

        String endpoint = resolveAttachDocumentEndpoint();
        if (String.isBlank(endpoint)) {
            System.debug(LoggingLevel.ERROR,
                'PelayoAttachDocumentService: missing endpoint configuration.');
            return;
        }

        // Build all payloads upfront (queries happen inside buildPayloads, respecting limits)
        List<String> payloads = PelayoAttachDocumentOutBoundStructure.createJSONPayloads(
            caseId, orderId, inputs
        );

        // ── One HTTP call per file ────────────────────────────────────────────
        for (Integer i = 0; i < payloads.size(); i++) {
            String requestBody = payloads.get(i);
            if (String.isBlank(requestBody)) {
                continue;
            }

            PelayoAttachDocumentOutBoundStructure.AttachDocumentResponse resp =
                callAttachDocumentService(endpoint, token, requestBody);

            // Best-effort platform event feedback (mirrors updateClaim pattern)
            try {
                Boolean ok = resp != null && resp.success == true;
                System.debug(JSON.serialize(resp));
                String  msg = resp != null ? resp.detail : null;
                PelayoWebServiceController.sendResponseEvent(ok, (String) caseId, msg);
            } catch (Exception e) {
                // Ignore event publish errors; do not fail the integration.
            }
        }
    }

    // ─── Endpoint resolution ──────────────────────────────────────────────────

    private static String resolveAttachDocumentEndpoint() {
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

        // Normalise: strip any existing operation suffix, then append /attachDocument
        if (base.endsWith(ATTACH_DOCUMENT_PATH)) {
            endpoint = base;
        } else if (base.endsWith('/')) {
            endpoint = base.left(base.length() - 1) + ATTACH_DOCUMENT_PATH;
        } else {
            // If the config already ends with a known operation path, replace the last segment
            Integer lastSlash = base.lastIndexOf('/');
            if (lastSlash > 8) {
                String lastSegment = base.substring(lastSlash);
                if (lastSegment.toLowerCase().startsWith('/update')
                    || lastSegment.toLowerCase().startsWith('/attach')) {
                    endpoint = base.substring(0, lastSlash) + ATTACH_DOCUMENT_PATH;
                } else {
                    endpoint = base + ATTACH_DOCUMENT_PATH;
                }
            } else {
                endpoint = base + ATTACH_DOCUMENT_PATH;
            }
        }

        return PelayoWebServiceController.normalizePelayoEndpoint(endpoint);
    }

    // ─── HTTP callout ─────────────────────────────────────────────────────────

    private static PelayoAttachDocumentOutBoundStructure.AttachDocumentResponse callAttachDocumentService(
        String endpoint,
        String token,
        String requestBody
    ) {
        PelayoAttachDocumentOutBoundStructure.AttachDocumentResponse serviceResponse =
            new PelayoAttachDocumentOutBoundStructure.AttachDocumentResponse();

        try {
            HttpRequest request = HttpRequestFactory.createHttpRequest(
                'POST',
                endpoint,
                new Map<String, String>{
                    'Accept'        => 'application/json',
                    'Content-Type'  => 'application/json',
                    'Authorization' => token
                },
                requestBody
            );
            System.debug(requestBody);
            Http http = new Http();
            HttpResponse response = http.send(request);
            System.debug('PelayoAttachDocumentService response: ' + response.getBody());

            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                serviceResponse = (PelayoAttachDocumentOutBoundStructure.AttachDocumentResponse)
                    JSON.deserialize(
                        response.getBody(),
                        PelayoAttachDocumentOutBoundStructure.AttachDocumentResponse.class
                    );
            } else {
                serviceResponse.success = false;
                serviceResponse.message =
                    'Failed to attach document in Pelayo service. Status Code: '
                    + response.getStatusCode();
                serviceResponse.errors = response.getBody();
                serviceResponse.detail = extractErrorDetail(serviceResponse.errors);
            }
        } catch (Exception e) {
            serviceResponse.success = false;
            serviceResponse.message =
                'Exception while calling Pelayo attachDocument service: ' + e.getMessage();
        }

        return serviceResponse;
    }

    private static String extractErrorDetail(String rawErrors) {
        if (String.isBlank(rawErrors)) {
            return null;
        }

        try {
            Object parsed = JSON.deserializeUntyped(rawErrors);
            if (parsed instanceof Map<String, Object>) {
                Map<String, Object> errorMap = (Map<String, Object>) parsed;

                Object detailValue = errorMap.get('detail');
                if (detailValue != null && !String.isBlank(String.valueOf(detailValue))) {
                    return String.valueOf(detailValue);
                }

                Object descriptionValue = errorMap.get('description');
                if (descriptionValue != null && !String.isBlank(String.valueOf(descriptionValue))) {
                    return String.valueOf(descriptionValue);
                }
            }
        } catch (Exception e) {
            // Ignore parsing issues and keep the original response shape.
        }

        return null;
    }

    // ─── Queueable ────────────────────────────────────────────────────────────

    public class AttachDocumentQueueable implements Queueable, Database.AllowsCallouts {
        private Id caseId;
        private Id orderId;
        private List<PelayoAttachDocumentOutBoundStructure.FileAttachmentInput> inputs;

        public AttachDocumentQueueable(
            Id caseId,
            Id orderId,
            List<PelayoAttachDocumentOutBoundStructure.FileAttachmentInput> inputs
        ) {
            this.caseId  = caseId;
            this.orderId = orderId;
            this.inputs  = inputs;
        }

        public void execute(QueueableContext context) {
            if (Test.isRunningTest() && !enableCalloutsInTests) {
                return;
            }
            callAttachDocumentsSync(caseId, orderId, inputs);
        }
    }
}