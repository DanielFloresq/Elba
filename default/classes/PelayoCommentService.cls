/**
 * @description       : Sends Comment payloads to Pelayo createComment endpoint.
 *                      Called after a Comments__c record with "Hito - " subject is created
 *                      for Pelayo cases to notify Pelayo of the comment.
 * @author            : Daniel Flores
 * @group             : Pelayo Integration
 * @last modified on  : 09-04-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class PelayoCommentService {

    private static final String PELAYO_ACCOUNT_CODE               = 'PLYO';
    private static final String CONFIG_LABEL_PELAYO_CREATE_COMMENT = 'Pelayo Create Comment';
    private static final String CREATE_COMMENT_PATH                = '/createComment';
    private static final String HITO_PREFIX                        = 'Hito - ';
    private static final String SMS_HITO_PREFIX                    = 'Hito - Envío de SMS';
    private static final String PELAYO_INTEGRATION_USER_NAME       = 'Pelayo Integration';

    @TestVisible
    static Boolean enableCalloutsInTests = false;

    // ─── Public entry point ───────────────────────────────────────────────────

    /**
     * @description Enqueues the comment creation callout asynchronously.
     * @author Daniel Flores | 06-04-2026
     * @param commentIds List of Comments__c Ids to process
     **/
    public static void enqueueCreate(List<Id> commentIds) {
        if (commentIds == null || commentIds.isEmpty()) {
            return;
        }
        System.enqueueJob(new CreateCommentQueueable(commentIds));
    }

    // ─── Sync execution ───────────────────────────────────────────────────────

    /**
     * @description Executes the comment creation callout synchronously.
     * @author Daniel Flores | 06-04-2026
     * @param commentIds List of Comments__c Ids to process
     **/
    @TestVisible
    static void callCreateCommentsSync(List<Id> commentIds) {
        if (commentIds == null || commentIds.isEmpty()) {
            return;
        }

        List<Comments__c> comments = queryComments(commentIds);
        Map<Id, Comments__c> commentsById = new Map<Id, Comments__c>(comments);

        Set<Id> pelayoCommentIds = new Set<Id>();
        for (Comments__c comm : comments) {
            if (isPelayoComment(comm)) {
                pelayoCommentIds.add(comm.Id);
            }
        }

        if (pelayoCommentIds.isEmpty()) {
            return;
        }

        String token = PelayoWebServiceController.getToken();
        if (String.isBlank(token)) {
            updateCommentsWithFailure(
                pelayoCommentIds,
                'PelayoCommentService: failed to obtain access token.'
            );
            return;
        }

        String endpoint = resolveCreateCommentEndpoint();
        if (String.isBlank(endpoint)) {
            updateCommentsWithFailure(
                pelayoCommentIds,
                'PelayoCommentService: missing endpoint configuration.'
            );
            return;
        }

        List<Comments__c> commentsToUpdate = new List<Comments__c>();
        
        for (Id commentId : pelayoCommentIds) {
            Comments__c comm = commentsById.get(commentId);

            PelayoCommentOutBoundStructure.CommentContext ctx = buildCommentContext(comm);
            if (ctx == null) {
                commentsToUpdate.add(buildCommentIntegrationUpdate(
                    comm.Id,
                    false,
                    'PelayoCommentService: unable to build comment context.'
                ));
                continue;
            }

            String requestBody = PelayoCommentOutBoundStructure.createJSON(ctx);
            if (String.isBlank(requestBody)) {
                commentsToUpdate.add(buildCommentIntegrationUpdate(
                    comm.Id,
                    false,
                    'PelayoCommentService: request body is empty.'
                ));
                continue;
            }

            PelayoCommentOutBoundStructure.CommentResponse resp =
                callCommentService(endpoint, token, requestBody);

            commentsToUpdate.add(buildCommentIntegrationUpdate(
                comm.Id,
                resp != null && resp.success == true,
                resp != null ? resp.message : 'Unknown response from Pelayo comment service.'
            ));

            // Best-effort platform event feedback
            sendResponseEvent(comm.Id, resp);
        }

        if (!commentsToUpdate.isEmpty()) {
            update commentsToUpdate;
        }
    }

    private static void updateCommentsWithFailure(Set<Id> commentIds, String message) {
        if (commentIds == null || commentIds.isEmpty()) {
            return;
        }

        List<Comments__c> commentsToUpdate = new List<Comments__c>();
        for (Id commentId : commentIds) {
            commentsToUpdate.add(buildCommentIntegrationUpdate(commentId, false, message));
        }

        update commentsToUpdate;
    }

    private static Comments__c buildCommentIntegrationUpdate(
        Id commentId,
        Boolean success,
        String message
    ) {
        return new Comments__c(
            Id = commentId,
            LastIntegrationDateTime__c = System.now(),
            LastIntegrationDescription__c = message,
            LastIntegration__c = success ? '' : buildCommentReprocessRoute(commentId)
        );
    }

    private static String buildCommentReprocessRoute(Id commentId) {
        return 'IntegrationsExtensionClass/createCommentPelayoService/commentId/'
            + String.valueOf(commentId);
    }

    // ─── Context building ─────────────────────────────────────────────────────

    @TestVisible
    private static PelayoCommentOutBoundStructure.CommentContext buildCommentContext(Comments__c comm) {
        if (comm == null) {
            return null;
        }

        PelayoCommentOutBoundStructure.CommentContext ctx = 
            new PelayoCommentOutBoundStructure.CommentContext();

        ctx.commentId = comm.Id;

        // Determine the primary record and extract siniestro data
        if (comm.Incident__c != null && comm.Incident__r != null) {
            if (comm.Incident__r.OrderService__r != null
                && comm.Incident__r.OrderService__r.CaseNumber__r != null) {
                ctx.idSiniestroElba = comm.Incident__r.OrderService__r.CaseNumber__r.CaseNumber;
                ctx.idSiniestroAseguradora =
                    comm.Incident__r.OrderService__r.CaseNumber__r.InsurerClaimReference__c;
                ctx.idEncargoElba = comm.Incident__r.OrderService__r.OrderNumber;
                ctx.idEncargoAseguradora = comm.Incident__r.OrderService__r.ChargeIdentifier__c;

                ctx.tipoDestinatario = 'PROVEEDOR';
                if (comm.Incident__r.OrderService__r.AccountId != null) {
                    ctx.identificadorDestinatario =
                        String.valueOf(comm.Incident__r.OrderService__r.AccountId);
                    ctx.nombreDestinatario = comm.Incident__r.OrderService__r.Account.Name;
                }
            } else if (comm.Incident__r.NestedCaseID__r != null) {
                ctx.idSiniestroElba = comm.Incident__r.NestedCaseID__r.CaseNumber;
                ctx.idSiniestroAseguradora =
                    comm.Incident__r.NestedCaseID__r.InsurerClaimReference__c;

                if (comm.Stakeholders__c != null && comm.Stakeholders__r != null) {
                    ctx.tipoDestinatario          = 'IMPLICADO';
                    ctx.identificadorDestinatario = String.valueOf(comm.Stakeholders__c);
                    ctx.nombreDestinatario        = comm.Stakeholders__r.Name;
                } else if (comm.Contact__c != null && comm.Contact__r != null) {
                    ctx.tipoDestinatario          = 'ASEGURADO';
                    ctx.identificadorDestinatario = String.valueOf(comm.Contact__c);
                    ctx.nombreDestinatario        = comm.Contact__r.Name;
                } else {
                    ctx.tipoDestinatario = 'ASEGURADO';
                }
            }
        } else if (comm.Order__c != null && comm.Order__r != null) {
            // Comment is on Order - get Case data via Order
            if (comm.Order__r.CaseNumber__r != null) {
                ctx.idSiniestroElba        = comm.Order__r.CaseNumber__r.CaseNumber;
                ctx.idSiniestroAseguradora = comm.Order__r.CaseNumber__r.InsurerClaimReference__c;
            }
            ctx.idEncargoElba        = comm.Order__r.OrderNumber;
            ctx.idEncargoAseguradora = comm.Order__r.ChargeIdentifier__c;

            // Destinatario: Provider (from Order)
            ctx.tipoDestinatario = 'PROVEEDOR';
            if (comm.Order__r.Account != null) {
                ctx.identificadorDestinatario = String.valueOf(comm.Order__r.AccountId);
                ctx.nombreDestinatario        = comm.Order__r.Account.Name;
            }
        } else if (comm.Case__c != null && comm.Case__r != null) {
            // Comment is on Case directly
            ctx.idSiniestroElba        = comm.Case__r.CaseNumber;
            ctx.idSiniestroAseguradora = comm.Case__r.InsurerClaimReference__c;

            // Destinatario: Asegurado or Stakeholder
            if (comm.Stakeholders__c != null && comm.Stakeholders__r != null) {
                ctx.tipoDestinatario          = 'IMPLICADO';
                ctx.identificadorDestinatario = String.valueOf(comm.Stakeholders__c);
                ctx.nombreDestinatario        = comm.Stakeholders__r.Name;
            } else if (comm.Contact__c != null && comm.Contact__r != null) {
                ctx.tipoDestinatario          = 'ASEGURADO';
                ctx.identificadorDestinatario = String.valueOf(comm.Contact__c);
                ctx.nombreDestinatario        = comm.Contact__r.Name;
            } else {
                ctx.tipoDestinatario = 'ASEGURADO';
            }
        }

        // Comment identifiers
        ctx.idComentarioElba = comm.Name;

        // Detalle
        ctx.autor     = comm.CreatedBy != null ? comm.CreatedBy.Name : null;
        ctx.titulo    = comm.Comment__c;
        ctx.mensaje   = comm.Message__c;
        ctx.privado   = false; // Default to public

        // Dates
        ctx.fechaCreacion     = comm.CreatedDate;
        ctx.fechaAlta         = comm.CreatedDate;
        ctx.usuarioAlta       = comm.CreatedBy != null ? comm.CreatedBy.Name : null;
        ctx.fechaModificacion = comm.LastModifiedDate;
        ctx.usuarioModificacion = comm.LastModifiedBy != null ? comm.LastModifiedBy.Name : null;

        return ctx;
    }

    // ─── Query ────────────────────────────────────────────────────────────────

    @TestVisible
    private static List<Comments__c> queryComments(List<Id> commentIds) {
        return [
            SELECT Id,
                   Name,
                   Comment__c,
                   Message__c,
                   Type__c,
                   Subtype__c,
                   CreatedDate,
                   LastModifiedDate,
                   CreatedBy.Name,
                   LastModifiedBy.Name,
                   Case__c,
                   Case__r.CaseNumber,
                   Case__r.InsurerClaimReference__c,
                   Case__r.GrandAccount__c,
                   Order__c,
                   Order__r.OrderNumber,
                   Order__r.ChargeIdentifier__c,
                   Order__r.AccountId,
                   Order__r.Account.Name,
                   Order__r.CaseNumber__c,
                   Order__r.CaseNumber__r.CaseNumber,
                   Order__r.CaseNumber__r.InsurerClaimReference__c,
                   Order__r.CaseNumber__r.GrandAccount__c,
                   Contact__c,
                   Contact__r.Name,
                   Stakeholders__c,
                   Stakeholders__r.Name,
                   Stakeholders__r.Case__r.GrandAccount__c,
                   Incident__c,
                   Incident__r.OrderService__c,
                   Incident__r.OrderService__r.OrderNumber,
                   Incident__r.OrderService__r.ChargeIdentifier__c,
                   Incident__r.OrderService__r.AccountId,
                   Incident__r.OrderService__r.Account.Name,
                   Incident__r.OrderService__r.CaseNumber__r.CaseNumber,
                   Incident__r.OrderService__r.CaseNumber__r.InsurerClaimReference__c,
                   Incident__r.OrderService__r.CaseNumber__r.GrandAccount__c,
                   Incident__r.NestedCaseID__r.CaseNumber,
                   Incident__r.NestedCaseID__r.InsurerClaimReference__c,
                   Incident__r.NestedCaseID__r.GrandAccount__c
            FROM Comments__c
            WHERE Id IN :commentIds
        ];
    }

    // ─── Validation ───────────────────────────────────────────────────────────

    /**
     * @description Checks if a comment should be sent to Pelayo.
     *              Requirements: Pelayo case (GrandAccount__c = 'PLYO') and Comment__c starts with "Hito - "
     * @author Daniel Flores | 09-04-2026
     * @param comm The Comments__c record to check
     * @return Boolean True if should be sent to Pelayo
     **/
    @TestVisible
    private static Boolean isPelayoComment(Comments__c comm) {
        if (comm == null) {
            return false;
        }

        if (String.isNotBlank(comm.Comment__c) && comm.Comment__c.startsWith(SMS_HITO_PREFIX)) {
            return false;
        }

        // Skip internal ELBA comments
        if (comm.Type__c == 'Comments' && comm.Subtype__c == 'ELBA') {
            return false;
        }

        // Skip if created by Pelayo Integration user
        if (comm.CreatedBy != null && comm.CreatedBy.Name == PELAYO_INTEGRATION_USER_NAME) {
            return false;
        }

        if (comm.Incident__c != null && comm.Incident__r != null) {
            if (comm.Incident__r.OrderService__r != null
                && comm.Incident__r.OrderService__r.CaseNumber__r != null
                && comm.Incident__r.OrderService__r.CaseNumber__r.GrandAccount__c == PELAYO_ACCOUNT_CODE) {
                return true;
            }

            if (comm.Incident__r.NestedCaseID__r != null
                && comm.Incident__r.NestedCaseID__r.GrandAccount__c == PELAYO_ACCOUNT_CODE) {
                return true;
            }
        }

        // Check Pelayo case via Order or Case
        if ( 
            comm.Order__c != null 
            && comm.Order__r != null 
            && comm.Order__r.CaseNumber__r != null 
            && comm.Order__r.CaseNumber__r.GrandAccount__c == PELAYO_ACCOUNT_CODE) {
            return true;
        }

        if (comm.Case__c != null 
            && comm.Case__r != null 
            && comm.Case__r.GrandAccount__c == PELAYO_ACCOUNT_CODE) {
            return true;
        }

        return false;
    }

    /**
     * @description Quick check if a comment has "Hito - " prefix (for trigger filter).
     * @author Daniel Flores | 06-04-2026
     * @param commentText The Comment__c field value
     * @return Boolean True if starts with "Hito - "
     **/
    public static Boolean hasHitoPrefix(String commentText) {
        return String.isNotBlank(commentText) && commentText.startsWith(HITO_PREFIX);
    }

    // ─── Endpoint resolution ──────────────────────────────────────────────────

    @TestVisible
    private static String resolveCreateCommentEndpoint() {
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;

        WebServiceUtils__mdt config;
        try {
            config = [
                SELECT Endpoint__c
                FROM WebServiceUtils__mdt
                WHERE MasterLabel = :CONFIG_LABEL_PELAYO_CREATE_COMMENT
                AND isSandbox__c = :isSandbox
                LIMIT 1
            ];
        } catch (Exception e) {
            // Fallback: try to build endpoint from existing Pelayo config
            try {
                config = [
                    SELECT Endpoint__c
                    FROM WebServiceUtils__mdt
                    WHERE MasterLabel LIKE 'Pelayo%'
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

        // Ensure it ends with /createComment
        if (base.endsWith(CREATE_COMMENT_PATH)) {
            endpoint = base;
        } else if (base.endsWith('/')) {
            endpoint = base.left(base.length() - 1) + CREATE_COMMENT_PATH;
        } else {
            // If config already points to a specific operation, replace last path segment
            Integer lastSlash = base.lastIndexOf('/');
            if (lastSlash > 8) {
                String lastSegment = base.substring(lastSlash);
                if (lastSegment.toLowerCase().contains('update')
                    || lastSegment.toLowerCase().contains('communication')
                    || lastSegment.toLowerCase().contains('attach')
                    || lastSegment.toLowerCase().contains('incident')
                    || lastSegment.toLowerCase().contains('command')) {
                    endpoint = base.substring(0, lastSlash) + CREATE_COMMENT_PATH;
                } else {
                    endpoint = base + CREATE_COMMENT_PATH;
                }
            } else {
                endpoint = base + CREATE_COMMENT_PATH;
            }
        }

        return PelayoWebServiceController.normalizePelayoEndpoint(endpoint);
    }

    // ─── HTTP callout ─────────────────────────────────────────────────────────

    @TestVisible
    private static PelayoCommentOutBoundStructure.CommentResponse callCommentService(
        String endpoint,
        String token,
        String requestBody
    ) {
        PelayoCommentOutBoundStructure.CommentResponse serviceResponse =
            new PelayoCommentOutBoundStructure.CommentResponse();

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

            System.debug('PelayoCommentService request body: ' + requestBody);

            Http http = new Http();
            HttpResponse response = http.send(request);

            System.debug('PelayoCommentService response: ' + response.getBody());

            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                serviceResponse = (PelayoCommentOutBoundStructure.CommentResponse)
                    JSON.deserialize(
                        response.getBody(),
                        PelayoCommentOutBoundStructure.CommentResponse.class
                    );
            } else {
                serviceResponse.success = false;
                serviceResponse.message =
                    'Failed to send comment to Pelayo service. Status Code: '
                    + response.getStatusCode();
                serviceResponse.errors = response.getBody();
            }
        } catch (Exception e) {
            serviceResponse.success = false;
            serviceResponse.message =
                'Exception while calling Pelayo comment service: ' + e.getMessage();
        }

        return serviceResponse;
    }

    // ─── Event publishing ─────────────────────────────────────────────────────

    private static void sendResponseEvent(Id commentId, PelayoCommentOutBoundStructure.CommentResponse resp) {
        try {
            Boolean ok  = resp != null && resp.success == true;
            String  msg = resp != null ? resp.message : null;
            PelayoWebServiceController.sendResponseEvent(ok, String.valueOf(commentId), msg);
        } catch (Exception e) {
            // Ignore event publish errors; do not fail the integration.
        }
    }

    // ─── Queueable class ──────────────────────────────────────────────────────

    public class CreateCommentQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> commentIds;

        public CreateCommentQueueable(List<Id> commentIds) {
            this.commentIds = commentIds;
        }

        public void execute(QueueableContext context) {
            if (Test.isRunningTest() && !enableCalloutsInTests) {
                return;
            }
            callCreateCommentsSync(commentIds);
        }
    }
}