/**
 * @description       : Sends Solicitation payloads to Pelayo createNotification endpoint.
 * @author            : Daniel Flores
 * @group             : Pelayo Integration
 * @last modified on  : 07-04-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class PelayoNotificationService {

    private static final String PELAYO_ACCOUNT_CODE = 'PLYO';
    private static final String CONFIG_LABEL_PELAYO_CREATE_NOTIFICATION = 'Pelayo Create Notification';
    private static final String CONFIG_LABEL_PELAYO_UPDATE_ASSIGNMENT = 'Update Pelayo Assignment';
    private static final String CREATE_NOTIFICATION_PATH = '/createNotification';
    private static final String PELAYO_INTEGRATION_USER_NAME = 'Pelayo Integration';

    @TestVisible
    static Boolean enableCalloutsInTests = false;

    public static void enqueueCreate(List<Id> solicitationIds) {
        if (solicitationIds == null || solicitationIds.isEmpty()) {
            return;
        }
        System.enqueueJob(new CreateNotificationQueueable(solicitationIds));
    }

    @TestVisible
    static void callCreateNotificationsSync(List<Id> solicitationIds) {
        if (solicitationIds == null || solicitationIds.isEmpty()) {
            return;
        }

        List<Solicitation__c> solicitations = querySolicitations(solicitationIds);
        Map<Id, Solicitation__c> solicitationsById = new Map<Id, Solicitation__c>(solicitations);

        Set<Id> pelayoSolicitationIds = new Set<Id>();
        for (Solicitation__c solicitation : solicitations) {
            if (isPelayoSolicitation(solicitation)) {
                pelayoSolicitationIds.add(solicitation.Id);
            }
        }

        if (pelayoSolicitationIds.isEmpty()) {
            return;
        }

        String token = PelayoWebServiceController.getToken();
        if (String.isBlank(token)) {
            updateSolicitationsWithFailure(
                pelayoSolicitationIds,
                'PelayoNotificationService: failed to obtain access token.'
            );
            return;
        }

        String endpoint = resolveCreateNotificationEndpoint();
        if (String.isBlank(endpoint)) {
            updateSolicitationsWithFailure(
                pelayoSolicitationIds,
                'PelayoNotificationService: missing endpoint configuration.'
            );
            return;
        }

        List<Solicitation__c> solicitationsToUpdate = new List<Solicitation__c>();
        for (Id solicitationId : pelayoSolicitationIds) {
            Solicitation__c solicitation = solicitationsById.get(solicitationId);

            PelayoNotificationOutBoundStructure.NotificationContext ctx = buildNotificationContext(solicitation);
            if (ctx == null) {
                solicitationsToUpdate.add(buildSolicitationIntegrationUpdate(
                    solicitation.Id,
                    false,
                    'PelayoNotificationService: unable to build solicitation context.'
                ));
                continue;
            }

            String requestBody = PelayoNotificationOutBoundStructure.createJSON(ctx);
            if (String.isBlank(requestBody)) {
                solicitationsToUpdate.add(buildSolicitationIntegrationUpdate(
                    solicitation.Id,
                    false,
                    'PelayoNotificationService: request body is empty.'
                ));
                continue;
            }

            PelayoNotificationOutBoundStructure.NotificationResponse resp =
                callNotificationService(endpoint, token, requestBody);

            solicitationsToUpdate.add(buildSolicitationIntegrationUpdate(
                solicitation.Id,
                resp != null && resp.success == true,
                resp != null ? resp.message : 'Unknown response from Pelayo notification service.'
            ));

            sendResponseEvent(solicitation.Id, resp);
        }

        if (!solicitationsToUpdate.isEmpty()) {
            update solicitationsToUpdate;
        }
    }

    private static void updateSolicitationsWithFailure(Set<Id> solicitationIds, String message) {
        if (solicitationIds == null || solicitationIds.isEmpty()) {
            return;
        }

        List<Solicitation__c> solicitationsToUpdate = new List<Solicitation__c>();
        for (Id solicitationId : solicitationIds) {
            solicitationsToUpdate.add(buildSolicitationIntegrationUpdate(solicitationId, false, message));
        }

        update solicitationsToUpdate;
    }

    private static Solicitation__c buildSolicitationIntegrationUpdate(
        Id solicitationId,
        Boolean success,
        String message
    ) {
        return new Solicitation__c(
            Id = solicitationId,
            LastIntegrationDateTime__c = System.now(),
            LastIntegrationDescription__c = message,
            LastIntegration__c = success ? '' : buildSolicitationReprocessRoute(solicitationId)
        );
    }

    private static String buildSolicitationReprocessRoute(Id solicitationId) {
        return 'IntegrationsExtensionClass/createNotificationPelayoService/solicitationId/'
            + String.valueOf(solicitationId);
    }

    @TestVisible
    private static List<Solicitation__c> querySolicitations(List<Id> solicitationIds) {
        return [
            SELECT Id,
                   Name,
                   Description__c,
                   RequestType__c,
                   Claim__c,
                   Claim__r.CaseNumber,
                   Claim__r.InsurerClaimReference__c,
                   Claim__r.GrandAccount__c,
                   Order__c,
                   Order__r.OrderNumber,
                   Order__r.CaseNumber__c,
                   Order__r.CaseNumber__r.CaseNumber,
                   Order__r.CaseNumber__r.InsurerClaimReference__c,
                   Order__r.CaseNumber__r.GrandAccount__c,
                   CreatedDate,
                   CreatedBy.Name,
                   LastModifiedDate,
                   LastModifiedBy.Name
            FROM Solicitation__c
            WHERE Id IN :solicitationIds
        ];
    }

    @TestVisible
    private static Boolean isPelayoSolicitation(Solicitation__c solicitation) {
        if (solicitation == null) {
            return false;
        }

        if (solicitation.CreatedBy != null
            && solicitation.CreatedBy.Name == PELAYO_INTEGRATION_USER_NAME) {
            return false;
        }

        if (solicitation.Order__c != null
            && solicitation.Order__r != null
            && solicitation.Order__r.CaseNumber__r != null
            && solicitation.Order__r.CaseNumber__r.GrandAccount__c == PELAYO_ACCOUNT_CODE) {
            return true;
        }

        if (solicitation.Claim__c != null
            && solicitation.Claim__r != null
            && solicitation.Claim__r.GrandAccount__c == PELAYO_ACCOUNT_CODE) {
            return true;
        }

        return false;
    }

    @TestVisible
    private static PelayoNotificationOutBoundStructure.NotificationContext buildNotificationContext(
        Solicitation__c solicitation
    ) {
        if (solicitation == null) {
            return null;
        }

        PelayoNotificationOutBoundStructure.NotificationContext ctx =
            new PelayoNotificationOutBoundStructure.NotificationContext();

        ctx.solicitationId = solicitation.Id;
        ctx.idNotificacionElba = solicitation.Name;
        ctx.idNotificacionAseguradora = buildExternalNotificationId(solicitation.Id);
        ctx.tipoSolicitudElba = solicitation.RequestType__c;
        ctx.descripcion = solicitation.Description__c;
        ctx.fechaAlta = solicitation.CreatedDate;
        ctx.usuarioAlta = solicitation.CreatedBy != null ? solicitation.CreatedBy.Name : null;
        ctx.fechaModificacion = solicitation.LastModifiedDate;
        ctx.usuarioModificacion = solicitation.LastModifiedBy != null ? solicitation.LastModifiedBy.Name : null;

        if (solicitation.Order__c != null && solicitation.Order__r != null) {
            ctx.idEncargoElba = solicitation.Order__r.OrderNumber;
            if (solicitation.Order__r.CaseNumber__r != null) {
                ctx.idSiniestroElba = solicitation.Order__r.CaseNumber__r.CaseNumber;
                ctx.idSiniestroAseguradora = solicitation.Order__r.CaseNumber__r.InsurerClaimReference__c;
            }
        }

        if (String.isBlank(ctx.idSiniestroElba)
            && solicitation.Claim__c != null
            && solicitation.Claim__r != null) {
            ctx.idSiniestroElba = solicitation.Claim__r.CaseNumber;
            ctx.idSiniestroAseguradora = solicitation.Claim__r.InsurerClaimReference__c;
        }

        if (String.isBlank(ctx.idSiniestroElba)) {
            return null;
        }

        return ctx;
    }

    @TestVisible
    private static String buildExternalNotificationId(Id solicitationId) {
        if (solicitationId == null) {
            return null;
        }

        String hex = EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(String.valueOf(solicitationId)))
        ).toLowerCase();

        if (hex.length() < 32) {
            return null;
        }

        return hex.substring(0, 8)
            + '-' + hex.substring(8, 12)
            + '-' + hex.substring(12, 16)
            + '-' + hex.substring(16, 20)
            + '-' + hex.substring(20, 32);
    }

    @TestVisible
    private static String resolveCreateNotificationEndpoint() {
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;

        WebServiceUtils__mdt config;
        try {
            config = [
                SELECT Endpoint__c
                FROM WebServiceUtils__mdt
                WHERE MasterLabel = :CONFIG_LABEL_PELAYO_CREATE_NOTIFICATION
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
        if (base.endsWith(CREATE_NOTIFICATION_PATH)) {
            endpoint = base;
        } else if (base.endsWith('/')) {
            endpoint = base.left(base.length() - 1) + CREATE_NOTIFICATION_PATH;
        } else {
            Integer lastSlash = base.lastIndexOf('/');
            if (lastSlash > 8) {
                String lastSegment = base.substring(lastSlash);
                if (lastSegment.toLowerCase().contains('update')
                    || lastSegment.toLowerCase().contains('attach')
                    || lastSegment.toLowerCase().contains('communication')
                    || lastSegment.toLowerCase().contains('incident')
                    || lastSegment.toLowerCase().contains('comment')
                    || lastSegment.toLowerCase().contains('notification')
                    || lastSegment.toLowerCase().contains('command')) {
                    endpoint = base.substring(0, lastSlash) + CREATE_NOTIFICATION_PATH;
                } else {
                    endpoint = base + CREATE_NOTIFICATION_PATH;
                }
            } else {
                endpoint = base + CREATE_NOTIFICATION_PATH;
            }
        }

        return PelayoWebServiceController.normalizePelayoEndpoint(endpoint);
    }

    @TestVisible
    private static PelayoNotificationOutBoundStructure.NotificationResponse callNotificationService(
        String endpoint,
        String token,
        String requestBody
    ) {
        PelayoNotificationOutBoundStructure.NotificationResponse serviceResponse =
            new PelayoNotificationOutBoundStructure.NotificationResponse();

        try {
            HttpRequest request = HttpRequestFactory.createHttpRequest(
                'POST',
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

            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                serviceResponse = (PelayoNotificationOutBoundStructure.NotificationResponse)
                    JSON.deserialize(
                        response.getBody(),
                        PelayoNotificationOutBoundStructure.NotificationResponse.class
                    );
            } else {
                serviceResponse.success = false;
                serviceResponse.message =
                    'Failed to send notification to Pelayo service. Status Code: '
                    + response.getStatusCode();
                serviceResponse.errors = response.getBody();
            }
        } catch (Exception e) {
            serviceResponse.success = false;
            serviceResponse.message =
                'Exception while calling Pelayo notification service: ' + e.getMessage();
        }

        return serviceResponse;
    }

    private static void sendResponseEvent(
        Id solicitationId,
        PelayoNotificationOutBoundStructure.NotificationResponse resp
    ) {
        try {
            Boolean ok = resp != null && resp.success == true;
            String msg = resp != null ? resp.message : null;
            PelayoWebServiceController.sendResponseEvent(ok, String.valueOf(solicitationId), msg);
        } catch (Exception e) {
            // Ignore event publish errors.
        }
    }

    public class CreateNotificationQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> solicitationIds;

        public CreateNotificationQueueable(List<Id> solicitationIds) {
            this.solicitationIds = solicitationIds;
        }

        public void execute(QueueableContext context) {
            if (Test.isRunningTest() && !enableCalloutsInTests) {
                return;
            }
            callCreateNotificationsSync(solicitationIds);
        }
    }
}