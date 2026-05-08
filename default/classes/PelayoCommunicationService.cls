/**
 * @description       : Sends SMS communication payloads to Pelayo.
 *                      Called after a successful SMS send from the newSmsLWC component
 *                      to notify Pelayo of the communication.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 06-04-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class PelayoCommunicationService {

    private static final String PELAYO_ACCOUNT_CODE              = 'PLYO';
    private static final String CONFIG_LABEL_PELAYO_COMMUNICATIONS = 'Pelayo Communications';
    private static final String CONFIG_LABEL_PELAYO_UPDATE_ASSIGNMENT = 'Update Pelayo Assignment';
    private static final String COMMUNICATIONS_PATH              = '/createCommunication';
    private static final String PELAYO_INTEGRATION_USER_NAME     = 'Pelayo Integration';

    @TestVisible
    static Boolean enableCalloutsInTests = false;

    // ─── Public entry point ───────────────────────────────────────────────────

    /**
     * @description Enqueues the communication callout asynchronously.
     * @author Daniel Flores | 01-04-2026
     * @param caseId       Case (siniestro) from which the SMS was sent
     * @param commentId    Id of the Comments__c record created for the SMS
     * @param phoneNumber  Destination phone number
     * @param textMessage  SMS message content
     * @param recipientType Recipient selected in the action
     **/
    public static void enqueue(Id caseId, Id commentId, String phoneNumber, String textMessage, String recipientType) {
        if (caseId == null || String.isBlank(phoneNumber) || String.isBlank(textMessage)) {
            return;
        }
        System.enqueueJob(new CommunicationQueueable(caseId, commentId, phoneNumber, textMessage, recipientType));
    }

    /**
     * @description Enqueues email communications to Pelayo for EmailMessage records.
     * @author Daniel Flores | 01-04-2026
     * @param emailMessageIds EmailMessage Ids to process
     **/
    public static void enqueueEmails(Set<Id> emailMessageIds) {
        if (emailMessageIds == null || emailMessageIds.isEmpty()) {
            return;
        }
        System.enqueueJob(new EmailCommunicationQueueable(new List<Id>(emailMessageIds)));
    }

    /**
     * @description Executes the communication callout synchronously.
     * @author Daniel Flores | 01-04-2026
     **/
    @TestVisible
    static void callCommunicationSync(Id caseId, Id commentId, String phoneNumber, String textMessage, String recipientType) {
        if (caseId == null) {
            return;
        }

        // Guard: only process Pelayo cases
        List<Case> cases = [SELECT Id, GrandAccount__c FROM Case WHERE Id = :caseId LIMIT 1];
        if (cases.isEmpty() || cases[0].GrandAccount__c != PELAYO_ACCOUNT_CODE) {
            return;
        }

        String token = PelayoWebServiceController.getToken();
        if (String.isBlank(token)) {
            System.debug(LoggingLevel.ERROR,
                'PelayoCommunicationService: failed to obtain access token.');
            return;
        }

        String endpoint = resolveCommunicationsEndpoint();
        if (String.isBlank(endpoint)) {
            System.debug(LoggingLevel.ERROR,
                'PelayoCommunicationService: missing endpoint configuration.');
            return;
        }

        String requestBody = PelayoCommunicationOutBoundStructure.createJSON(
            caseId, commentId, phoneNumber, textMessage, recipientType
        );

        if (String.isBlank(requestBody)) {
            return;
        }

        PelayoCommunicationOutBoundStructure.CommunicationResponse resp =
            callCommunicationService(endpoint, token, requestBody);

        // Best-effort platform event feedback
        try {
            Boolean ok = resp != null && resp.success == true;
            String  msg = resp != null ? resp.message : null;
            PelayoWebServiceController.sendResponseEvent(ok, (String) caseId, msg);
        } catch (Exception e) {
            // Ignore event publish errors; do not fail the integration.
        }

        updateIntegrationTimestamps(new Set<Id>{ caseId }, new Set<Id>());
    }

    /**
     * @description Executes email communication callouts synchronously.
     * @author Daniel Flores | 01-04-2026
     * @param emailMessageIds EmailMessage Ids to process
     **/
    @TestVisible
    static void callEmailCommunicationsSync(Set<Id> emailMessageIds) {
        if (emailMessageIds == null || emailMessageIds.isEmpty()) {
            return;
        }

        String token = PelayoWebServiceController.getToken();
        if (String.isBlank(token)) {
            System.debug(LoggingLevel.ERROR,
                'PelayoCommunicationService: failed to obtain access token for email communications.');
            return;
        }

        String endpoint = resolveCommunicationsEndpoint();
        if (String.isBlank(endpoint)) {
            System.debug(LoggingLevel.ERROR,
                'PelayoCommunicationService: missing endpoint configuration for email communications.');
            return;
        }

        List<EmailMessage> emails = [
            SELECT Id,
                ParentId,
                RelatedToId,
                Incoming,
                Subject,
                HtmlBody,
                TextBody,
                FromAddress,
                ToAddress,
                CcAddress,
                BccAddress,
                MessageDate,
                CreatedDate,
                CreatedBy.Name
            FROM EmailMessage
            WHERE Id IN :emailMessageIds
        ];

        Set<Id> caseIds = new Set<Id>();
        Set<Id> orderIds = new Set<Id>();
        Map<Id, Id> primaryRecordIdByEmailId = new Map<Id, Id>();

        for (EmailMessage em : emails) {
            if (em == null || em.Incoming == true) {
                continue;
            }
            if (em.CreatedBy != null && em.CreatedBy.Name == PELAYO_INTEGRATION_USER_NAME) {
                continue;
            }

            Id primaryRecordId = resolvePrimaryRecordId(em);
            if (primaryRecordId == null) {
                continue;
            }

            primaryRecordIdByEmailId.put(em.Id, primaryRecordId);

            if (primaryRecordId.getSObjectType() == Case.SObjectType) {
                caseIds.add(primaryRecordId);
            } else if (primaryRecordId.getSObjectType() == Order.SObjectType) {
                orderIds.add(primaryRecordId);
            }
        }

        if (primaryRecordIdByEmailId.isEmpty()) {
            return;
        }

        Map<Id, Case> casesById = caseIds.isEmpty()
            ? new Map<Id, Case>()
            : new Map<Id, Case>([
                SELECT Id, CaseNumber, InsurerClaimReference__c, GrandAccount__c, Contact.Name
                FROM Case
                WHERE Id IN :caseIds
            ]);

        Map<Id, Order> ordersById = orderIds.isEmpty()
            ? new Map<Id, Order>()
            : new Map<Id, Order>([
                SELECT Id,
                    OrderNumber,
                    ChargeIdentifier__c,
                    BillToContact.Name,
                    CaseNumber__c,
                    CaseNumber__r.CaseNumber,
                    CaseNumber__r.InsurerClaimReference__c,
                    CaseNumber__r.GrandAccount__c
                FROM Order
                WHERE Id IN :orderIds
            ]);

        Map<Id, List<String>> attachmentDocumentIdsByEmailId = new Map<Id, List<String>>();
        Set<Id> caseIdsToStamp = new Set<Id>();
        Set<Id> orderIdsToStamp = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :primaryRecordIdByEmailId.keySet()
        ]) {
            if (!attachmentDocumentIdsByEmailId.containsKey(cdl.LinkedEntityId)) {
                attachmentDocumentIdsByEmailId.put(cdl.LinkedEntityId, new List<String>());
            }
            attachmentDocumentIdsByEmailId.get(cdl.LinkedEntityId).add(String.valueOf(cdl.ContentDocumentId));
        }

        for (EmailMessage em : emails) {
            Id primaryRecordId = primaryRecordIdByEmailId.get(em.Id);
            if (primaryRecordId == null) {
                continue;
            }

            PelayoCommunicationOutBoundStructure.EmailCommunicationContext ctx =
                buildEmailContext(
                    em,
                    primaryRecordId,
                    casesById.get(primaryRecordId),
                    ordersById.get(primaryRecordId),
                    attachmentDocumentIdsByEmailId.get(em.Id)
                );

            if (ctx == null) {
                continue;
            }

            String requestBody = PelayoCommunicationOutBoundStructure.createEmailJSON(ctx);
            if (String.isBlank(requestBody)) {
                continue;
            }

            PelayoCommunicationOutBoundStructure.CommunicationResponse resp =
                callCommunicationService(endpoint, token, requestBody);

            if (primaryRecordId.getSObjectType() == Case.SObjectType) {
                caseIdsToStamp.add(primaryRecordId);
            } else if (primaryRecordId.getSObjectType() == Order.SObjectType) {
                orderIdsToStamp.add(primaryRecordId);
            }

            try {
                Boolean ok = resp != null && resp.success == true;
                String msg = resp != null ? resp.message : null;
                PelayoWebServiceController.sendResponseEvent(ok, String.valueOf(primaryRecordId), msg);
            } catch (Exception e) {
                // Ignore event publish errors; do not fail the integration.
            }
        }

        updateIntegrationTimestamps(caseIdsToStamp, orderIdsToStamp);
    }

    @TestVisible
    private static void updateIntegrationTimestamps(Set<Id> caseIds, Set<Id> orderIds) {
        List<SObject> recordsToUpdate = new List<SObject>();

        if (caseIds != null) {
            for (Id caseId : caseIds) {
                if (caseId != null) {
                    recordsToUpdate.add(new Case(
                        Id = caseId,
                        LastIntegrationDateTime__c = System.now()
                    ));
                }
            }
        }

        if (orderIds != null) {
            for (Id orderId : orderIds) {
                if (orderId != null) {
                    recordsToUpdate.add(new Order(
                        Id = orderId,
                        LastIntegrationDateTime__c = System.now()
                    ));
                }
            }
        }

        if (recordsToUpdate.isEmpty()) {
            return;
        }

        Boolean originalCaseBypass = PelayoUpdateClaimTriggerLogic.bypassExternalActions;
        Boolean originalOrderBypass = OrderTriggerLogic.bypassExternalActions;

        PelayoUpdateClaimTriggerLogic.bypassExternalActions = true;
        OrderTriggerLogic.bypassExternalActions = true;
        try {
            update recordsToUpdate;
        } finally {
            PelayoUpdateClaimTriggerLogic.bypassExternalActions = originalCaseBypass;
            OrderTriggerLogic.bypassExternalActions = originalOrderBypass;
        }
    }

    @TestVisible
    private static Id resolvePrimaryRecordId(EmailMessage em) {
        if (em == null) {
            return null;
        }

        List<Id> candidateIds = new List<Id>{ em.RelatedToId, em.ParentId };

        for (Id candidateId : candidateIds) {
            if (candidateId != null && candidateId.getSObjectType() == Order.SObjectType) {
                return candidateId;
            }
        }
        for (Id candidateId : candidateIds) {
            if (candidateId != null && candidateId.getSObjectType() == Case.SObjectType) {
                return candidateId;
            }
        }
        return null;
    }

    @TestVisible
    private static PelayoCommunicationOutBoundStructure.EmailCommunicationContext buildEmailContext(
        EmailMessage em,
        Id primaryRecordId,
        Case relatedCase,
        Order relatedOrder,
        List<String> attachmentDocumentIds
    ) {
        if (em == null || primaryRecordId == null) {
            return null;
        }

        PelayoCommunicationOutBoundStructure.EmailCommunicationContext ctx =
            new PelayoCommunicationOutBoundStructure.EmailCommunicationContext();

        if (primaryRecordId.getSObjectType() == Case.SObjectType) {
            if (relatedCase == null || relatedCase.GrandAccount__c != PELAYO_ACCOUNT_CODE) {
                return null;
            }
            ctx.idSiniestroElba = relatedCase.CaseNumber;
            ctx.idSiniestroAseguradora = relatedCase.InsurerClaimReference__c;
            ctx.tipoDestinatario = 'AS';
            ctx.nombreDestinatario = relatedCase.Contact != null ? relatedCase.Contact.Name : null;
        } else if (primaryRecordId.getSObjectType() == Order.SObjectType) {
            if (relatedOrder == null
                || relatedOrder.CaseNumber__c == null
                || relatedOrder.CaseNumber__r == null
                || relatedOrder.CaseNumber__r.GrandAccount__c != PELAYO_ACCOUNT_CODE) {
                return null;
            }
            ctx.idSiniestroElba = relatedOrder.CaseNumber__r.CaseNumber;
            ctx.idSiniestroAseguradora = relatedOrder.CaseNumber__r.InsurerClaimReference__c;
            ctx.idEncargoElba = relatedOrder.OrderNumber;
            ctx.idEncargoAseguradora = relatedOrder.ChargeIdentifier__c;
            ctx.tipoDestinatario = 'PE';
            ctx.nombreDestinatario = relatedOrder.BillToContact != null ? relatedOrder.BillToContact.Name : null;
        } else {
            return null;
        }

        ctx.idComunicacionElba = String.valueOf(em.Id);
        Datetime communicationDate = em.MessageDate != null ? em.MessageDate : em.CreatedDate;
        ctx.fechaAlta = communicationDate != null
            ? communicationDate.format('yyyy-MM-dd\'T\'HH:mm:ss')
            : null;
        ctx.usuarioAlta = em.CreatedBy != null ? em.CreatedBy.Name : null;
        ctx.fromAddress = em.FromAddress;
        ctx.toAddress = em.ToAddress;
        ctx.ccAddress = em.CcAddress;
        ctx.bccAddress = em.BccAddress;
        ctx.subject = em.Subject;
        ctx.body = String.isNotBlank(em.TextBody) ? em.TextBody : em.HtmlBody;
        ctx.attachmentDocumentIds = attachmentDocumentIds != null
            ? new List<String>(attachmentDocumentIds)
            : new List<String>();

        return ctx;
    }

    // ─── Endpoint resolution ──────────────────────────────────────────────────

    private static String resolveCommunicationsEndpoint() {
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;

        WebServiceUtils__mdt config;
        try {
            config = [
                SELECT Endpoint__c
                FROM WebServiceUtils__mdt
                WHERE MasterLabel = :CONFIG_LABEL_PELAYO_COMMUNICATIONS
                AND isSandbox__c = :isSandbox
                LIMIT 1
            ];
        } catch (Exception e) {
            // Fallback: reuse assignment endpoint config and replace operation path
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

        // Ensure it ends with /communications
        if (base.endsWith(COMMUNICATIONS_PATH)) {
            endpoint = base;
        } else if (base.endsWith('/')) {
            endpoint = base.left(base.length() - 1) + COMMUNICATIONS_PATH;
        } else {
            // If config already points to a specific operation, replace last path segment
            Integer lastSlash = base.lastIndexOf('/');
            if (lastSlash > 8) {
                String lastSegment = base.substring(lastSlash);
                if (lastSegment.toLowerCase().contains('update')
                    || lastSegment.toLowerCase().contains('attach')
                    || lastSegment.toLowerCase().contains('communication')) {
                    endpoint = base.substring(0, lastSlash) + COMMUNICATIONS_PATH;
                } else {
                    endpoint = base + COMMUNICATIONS_PATH;
                }
            } else {
                endpoint = base + COMMUNICATIONS_PATH;
            }
        }

        return PelayoWebServiceController.normalizePelayoEndpoint(endpoint);
    }

    // ─── HTTP callout ─────────────────────────────────────────────────────────

    private static PelayoCommunicationOutBoundStructure.CommunicationResponse callCommunicationService(
        String endpoint,
        String token,
        String requestBody
    ) {
        PelayoCommunicationOutBoundStructure.CommunicationResponse serviceResponse =
            new PelayoCommunicationOutBoundStructure.CommunicationResponse();

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

            System.debug('PelayoCommunicationService request body: ' + requestBody);

            Http http = new Http();
            HttpResponse response = http.send(request);

            System.debug('PelayoCommunicationService response: ' + response.getBody());

            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                serviceResponse = (PelayoCommunicationOutBoundStructure.CommunicationResponse)
                    JSON.deserialize(
                        response.getBody(),
                        PelayoCommunicationOutBoundStructure.CommunicationResponse.class
                    );
            } else {
                serviceResponse.success = false;
                serviceResponse.message =
                    'Failed to send communication to Pelayo service. Status Code: '
                    + response.getStatusCode();
                serviceResponse.errors = response.getBody();
            }
        } catch (Exception e) {
            serviceResponse.success = false;
            serviceResponse.message =
                'Exception while calling Pelayo communications service: ' + e.getMessage();
        }

        return serviceResponse;
    }

    // ─── Queueable ────────────────────────────────────────────────────────────

    public class CommunicationQueueable implements Queueable, Database.AllowsCallouts {
        private Id     caseId;
        private Id     commentId;
        private String phoneNumber;
        private String textMessage;
        private String recipientType;

        public CommunicationQueueable(Id caseId, Id commentId, String phoneNumber, String textMessage, String recipientType) {
            this.caseId      = caseId;
            this.commentId   = commentId;
            this.phoneNumber = phoneNumber;
            this.textMessage = textMessage;
            this.recipientType = recipientType;
        }

        public void execute(QueueableContext context) {
            if (Test.isRunningTest() && !enableCalloutsInTests) {
                return;
            }
            callCommunicationSync(caseId, commentId, phoneNumber, textMessage, recipientType);
        }
    }

    public class EmailCommunicationQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> emailMessageIds;

        public EmailCommunicationQueueable(List<Id> emailMessageIds) {
            this.emailMessageIds = emailMessageIds;
        }

        public void execute(QueueableContext context) {
            if (Test.isRunningTest() && !enableCalloutsInTests) {
                return;
            }
            callEmailCommunicationsSync(new Set<Id>(emailMessageIds));
        }
    }
}