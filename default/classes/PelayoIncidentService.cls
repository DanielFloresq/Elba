/**
 * @description       : Sends Incident payloads to Pelayo createIncident endpoint.
 *                      Called after an Incident is created in ELBA for Pelayo cases
 *                      to notify Pelayo of the incident.
 * @author            : Daniel Flores
 * @group             : Pelayo Integration
 * @last modified on  : 06-04-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class PelayoIncidentService {

    private static final String PELAYO_ACCOUNT_CODE                = 'PLYO';
    private static final String CONFIG_LABEL_PELAYO_CREATE_INCIDENT = 'Pelayo Create Incident';
    private static final String CREATE_INCIDENT_PATH               = '/createIncident';
    private static final String PELAYO_INTEGRATION_USER_NAME       = 'Pelayo Integration';

    @TestVisible
    static Boolean enableCalloutsInTests = false;

    // ─── Public entry point ───────────────────────────────────────────────────

    /**
     * @description Enqueues the incident creation callout asynchronously.
     * @author Daniel Flores | 06-04-2026
     * @param incidentIds List of Incident Ids to process
     **/
    public static void enqueueCreate(List<Id> incidentIds) {
        if (incidentIds == null || incidentIds.isEmpty()) {
            return;
        }
        System.enqueueJob(new CreateIncidentQueueable(incidentIds));
    }

    /**
     * @description Enqueues the incident update callout asynchronously.
     * @author Daniel Flores | 06-04-2026
     * @param incidentIds List of Incident Ids to process
     **/
    public static void enqueueUpdate(List<Id> incidentIds) {
        if (incidentIds == null || incidentIds.isEmpty()) {
            return;
        }
        System.enqueueJob(new UpdateIncidentQueueable(incidentIds));
    }

    // ─── Sync execution ───────────────────────────────────────────────────────

    /**
     * @description Executes the incident creation callout synchronously.
     * @author Daniel Flores | 06-04-2026
     * @param incidentIds List of Incident Ids to process
     **/
    @TestVisible
    static void callCreateIncidentsSync(List<Id> incidentIds) {
        if (incidentIds == null || incidentIds.isEmpty()) {
            return;
        }

        List<Incident> incidents = queryIncidents(incidentIds);
        Map<Id, Incident> incidentsById = new Map<Id, Incident>(incidents);
        Set<Id> pelayoIncidentIds = collectPelayoIncidentIds(incidents);

        if (pelayoIncidentIds.isEmpty()) {
            return;
        }

        String token = PelayoWebServiceController.getToken();
        if (String.isBlank(token)) {
            updateIncidentsWithFailure(
                pelayoIncidentIds,
                'PelayoIncidentService: failed to obtain access token.',
                false
            );
            return;
        }

        String endpoint = resolveCreateIncidentEndpoint();
        if (String.isBlank(endpoint)) {
            updateIncidentsWithFailure(
                pelayoIncidentIds,
                'PelayoIncidentService: missing endpoint configuration.',
                false
            );
            return;
        }

        List<Incident> incidentsToUpdate = new List<Incident>();
        
        for (Id incidentId : pelayoIncidentIds) {
            Incident inc = incidentsById.get(incidentId);

            PelayoIncidentOutBoundStructure.IncidentContext ctx = buildIncidentContext(inc);
            if (ctx == null) {
                incidentsToUpdate.add(buildIncidentIntegrationUpdate(
                    inc.Id,
                    false,
                    'PelayoIncidentService: unable to build incident context.',
                    null,
                    false
                ));
                continue;
            }

            String requestBody = PelayoIncidentOutBoundStructure.createJSON(ctx);
            if (String.isBlank(requestBody)) {
                incidentsToUpdate.add(buildIncidentIntegrationUpdate(
                    inc.Id,
                    false,
                    'PelayoIncidentService: request body is empty.',
                    null,
                    false
                ));
                continue;
            }

            PelayoIncidentOutBoundStructure.IncidentResponse resp =
                callIncidentService(endpoint, token, requestBody);

            incidentsToUpdate.add(buildIncidentIntegrationUpdate(
                inc.Id,
                resp != null && resp.success == true,
                resp != null ? resp.message : 'Unknown response from Pelayo incident service.',
                resp != null ? resp.idIncidenciaAseguradora : null,
                false
            ));

            // Best-effort platform event feedback
            sendResponseEvent(inc.Id, resp);
        }

        updateIncidentIntegrationFields(incidentsToUpdate);
    }

    /**
     * @description Executes the incident update callout synchronously.
     * @author Daniel Flores | 06-04-2026
     * @param incidentIds List of Incident Ids to process
     **/
    @TestVisible
    static void callUpdateIncidentsSync(List<Id> incidentIds) {
        if (incidentIds == null || incidentIds.isEmpty()) {
            return;
        }

        List<Incident> incidents = queryIncidents(incidentIds);
        Map<Id, Incident> incidentsById = new Map<Id, Incident>(incidents);
        Set<Id> pelayoIncidentIds = collectPelayoIncidentIds(incidents);

        if (pelayoIncidentIds.isEmpty()) {
            return;
        }

        String token = PelayoWebServiceController.getToken();
        if (String.isBlank(token)) {
            updateIncidentsWithFailure(
                pelayoIncidentIds,
                'PelayoIncidentService: failed to obtain access token for update.',
                true
            );
            return;
        }

        String endpoint = resolveCreateIncidentEndpoint();
        if (String.isBlank(endpoint)) {
            updateIncidentsWithFailure(
                pelayoIncidentIds,
                'PelayoIncidentService: missing endpoint configuration for update.',
                true
            );
            return;
        }

        List<Incident> incidentsToUpdate = new List<Incident>();
        
        for (Id incidentId : pelayoIncidentIds) {
            Incident inc = incidentsById.get(incidentId);

            PelayoIncidentOutBoundStructure.IncidentContext ctx = buildIncidentContext(inc);
            if (ctx == null) {
                incidentsToUpdate.add(buildIncidentIntegrationUpdate(
                    inc.Id,
                    false,
                    'PelayoIncidentService: unable to build incident update context.',
                    null,
                    true
                ));
                continue;
            }

            String requestBody = PelayoIncidentOutBoundStructure.createUpdateJSON(ctx);
            if (String.isBlank(requestBody)) {
                incidentsToUpdate.add(buildIncidentIntegrationUpdate(
                    inc.Id,
                    false,
                    'PelayoIncidentService: update request body is empty.',
                    null,
                    true
                ));
                continue;
            }

            PelayoIncidentOutBoundStructure.IncidentResponse resp =
                callIncidentService(endpoint, token, requestBody);

            incidentsToUpdate.add(buildIncidentIntegrationUpdate(
                inc.Id,
                resp != null && resp.success == true,
                resp != null ? resp.message : 'Unknown response from Pelayo incident update service.',
                resp != null ? resp.idIncidenciaAseguradora : null,
                true
            ));

            // Best-effort platform event feedback
            sendResponseEvent(inc.Id, resp);
        }

        updateIncidentIntegrationFields(incidentsToUpdate);
    }

    private static Set<Id> collectPelayoIncidentIds(List<Incident> incidents) {
        Set<Id> pelayoIncidentIds = new Set<Id>();
        if (incidents == null) {
            return pelayoIncidentIds;
        }

        for (Incident inc : incidents) {
            if (isPelayoIncident(inc)) {
                pelayoIncidentIds.add(inc.Id);
            }
        }

        return pelayoIncidentIds;
    }

    private static void updateIncidentsWithFailure(Set<Id> incidentIds, String message, Boolean isUpdateCall) {
        if (incidentIds == null || incidentIds.isEmpty()) {
            return;
        }

        List<Incident> incidentsToUpdate = new List<Incident>();
        for (Id incidentId : incidentIds) {
            incidentsToUpdate.add(
                buildIncidentIntegrationUpdate(incidentId, false, message, null, isUpdateCall)
            );
        }

        updateIncidentIntegrationFields(incidentsToUpdate);
    }

    private static Incident buildIncidentIntegrationUpdate(
        Id incidentId,
        Boolean success,
        String message,
        String externalId,
        Boolean isUpdateCall
    ) {
        Incident incidentToUpdate = new Incident(
            Id = incidentId,
            LastIntegrationDateTime__c = System.now(),
            LastIntegrationDescription__c = message,
            LastIntegration__c = success ? '' : buildIncidentReprocessRoute(incidentId, isUpdateCall)
        );

        if (success && String.isNotBlank(externalId)) {
            incidentToUpdate.ExternalId__c = externalId;
        }

        return incidentToUpdate;
    }

    private static void updateIncidentIntegrationFields(List<Incident> incidentsToUpdate) {
        if (incidentsToUpdate == null || incidentsToUpdate.isEmpty()) {
            return;
        }

        IncidentTriggerContext.bypassExternalActions = true;
        try {
            update incidentsToUpdate;
        } finally {
            IncidentTriggerContext.bypassExternalActions = false;
        }
    }

    private static String buildIncidentReprocessRoute(Id incidentId, Boolean isUpdateCall) {
        return 'IntegrationsExtensionClass/'
            + (isUpdateCall ? 'updateIncidentPelayoService' : 'createIncidentPelayoService')
            + '/incidentId/'
            + String.valueOf(incidentId);
    }

    // ─── Context building ─────────────────────────────────────────────────────

    @TestVisible
    private static PelayoIncidentOutBoundStructure.IncidentContext buildIncidentContext(Incident inc) {
        if (inc == null || (inc.OrderService__c == null && inc.NestedCaseID__c == null)) {
            return null;
        }

        PelayoIncidentOutBoundStructure.IncidentContext ctx = 
            new PelayoIncidentOutBoundStructure.IncidentContext();

        ctx.incidentId = inc.Id;

        // Siniestro data from related Case (via Order)
        if (inc.OrderService__r != null && inc.OrderService__r.CaseNumber__r != null) {
            ctx.idSiniestroElba        = inc.OrderService__r.CaseNumber__r.CaseNumber;
        } else if (inc.NestedCaseID__r != null) {
            // Fallback for incidents created directly on Case without Order
            ctx.idSiniestroElba        = inc.NestedCaseID__r.CaseNumber;
        }

        ctx.idSiniestroAseguradora = resolvePelayoLinkReference(inc);

        // Encargo data from Order
        if (inc.OrderService__r != null) {
            ctx.idEncargoElba = inc.OrderService__r.OrderNumber;
        }

        // Service data
        ctx.idServicioElba = inc.OrderService__r != null ? inc.OrderService__r.Service__c : null;

        // Incident identifiers
        ctx.idIncidenciaElba = String.valueOf(inc.Id);

        // Incident type mapping
        ctx.tipo = PelayoIncidentOutBoundStructure.mapTypeToPelayo(inc.Type);

        // Reason and sub-reason (API values from picklist)
        ctx.motivo    = inc.Reason__c;
        ctx.submotivo = inc.Sub_Reason__c;

        // Origin and channel
        ctx.origen = inc.Origin__c;
        ctx.canal  = inc.Channel__c != null ? inc.Channel__c : 'EB';

        // Management team
        ctx.equipoGestion = inc.ManagementTeam__c;

        // Responsible party
        ctx.responsableIncidencias = inc.Owner.Name;
        ctx.tipoCausante           = inc.ResponsiblePartyType__c;
        ctx.causante               = inc.ResponsibleParty__c;

        // Repairer name if available
        if (String.isBlank(ctx.causante) && inc.Repairer__r != null) {
            ctx.causante = inc.Repairer__r.Name;
        }

        // Status mapping
        ctx.estado      = PelayoIncidentOutBoundStructure.mapStatusToEstado(inc.Status);
        ctx.fechaEstado = inc.StartDateTime;

        // Description
        ctx.descripcion = inc.Description;

        // Dates
        ctx.fechaGrabacion = inc.CreatedDate;
        ctx.fechaAlta      = inc.CreatedDate;
        ctx.usuarioAlta    = inc.CreatedBy.Name;

        return ctx;
    }

    @TestVisible
    private static String resolvePelayoLinkReference(Incident inc) {
        if (inc == null) {
            return null;
        }

        if (String.isNotBlank(inc.ExternalId__c)) {
            return inc.ExternalId__c;
        }

        if (inc.OrderService__r != null && inc.OrderService__r.CaseNumber__r != null) {
            return inc.OrderService__r.CaseNumber__r.InsurerClaimReference__c;
        }

        if (inc.NestedCaseID__r != null) {
            return inc.NestedCaseID__r.InsurerClaimReference__c;
        }

        return null;
    }

    // ─── Query ────────────────────────────────────────────────────────────────

    @TestVisible
    private static List<Incident> queryIncidents(List<Id> incidentIds) {
        return [
            SELECT Id,
                   Subject,
                   Description,
                   Status,
                   Priority,
                   Type,
                   Reason__c,
                   Sub_Reason__c,
                   Origin__c,
                   Channel__c,
                   ManagementTeam__c,
                   ResponsiblePartyType__c,
                   ResponsibleParty__c,
                   Result__c,
                   ExternalId__c,
                   StartDateTime,
                   CreatedDate,
                   CreatedBy.Name,
                   Owner.Name,
                   OrderService__c,
                   OrderService__r.OrderNumber,
                   OrderService__r.Service__c,
                   OrderService__r.ChargeIdentifier__c,
                   OrderService__r.CaseNumber__c,
                   OrderService__r.CaseNumber__r.CaseNumber,
                   OrderService__r.CaseNumber__r.InsurerClaimReference__c,
                   OrderService__r.CaseNumber__r.GrandAccount__c,
                   NestedCaseID__c,
                   NestedCaseID__r.CaseNumber,
                   NestedCaseID__r.InsurerClaimReference__c,
                   NestedCaseID__r.GrandAccount__c,
                   Repairer__c,
                   Repairer__r.Name
            FROM Incident
            WHERE Id IN :incidentIds
        ];
    }

    // ─── Validation ───────────────────────────────────────────────────────────

    @TestVisible
    private static Boolean isPelayoIncident(Incident inc) {
        if (inc == null) {
            return false;
        }

        // Check via Order -> Case relationship
        if (inc.OrderService__r != null 
            && inc.OrderService__r.CaseNumber__r != null 
            && inc.OrderService__r.CaseNumber__r.GrandAccount__c == PELAYO_ACCOUNT_CODE) {
            return true;
        }

        // Fallback: check via direct Case relationship if available
        if (inc.NestedCaseID__r != null 
            && inc.NestedCaseID__r.GrandAccount__c == PELAYO_ACCOUNT_CODE) {
            return true;
        }

        return false;
    }

    // ─── Endpoint resolution ──────────────────────────────────────────────────

    @TestVisible
    private static String resolveCreateIncidentEndpoint() {
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;

        WebServiceUtils__mdt config;
        try {
            config = [
                SELECT Endpoint__c
                FROM WebServiceUtils__mdt
                WHERE MasterLabel = :CONFIG_LABEL_PELAYO_CREATE_INCIDENT
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

        // Ensure it ends with /createIncident
        if (base.endsWith(CREATE_INCIDENT_PATH)) {
            endpoint = base;
        } else if (base.endsWith('/')) {
            endpoint = base.left(base.length() - 1) + CREATE_INCIDENT_PATH;
        } else {
            // If config already points to a specific operation, replace last path segment
            Integer lastSlash = base.lastIndexOf('/');
            if (lastSlash > 8) {
                String lastSegment = base.substring(lastSlash);
                if (lastSegment.toLowerCase().contains('update')
                    || lastSegment.toLowerCase().contains('communication')
                    || lastSegment.toLowerCase().contains('attach')
                    || lastSegment.toLowerCase().contains('command')) {
                    endpoint = base.substring(0, lastSlash) + CREATE_INCIDENT_PATH;
                } else {
                    endpoint = base + CREATE_INCIDENT_PATH;
                }
            } else {
                endpoint = base + CREATE_INCIDENT_PATH;
            }
        }

        return PelayoWebServiceController.normalizePelayoEndpoint(endpoint);
    }

    // ─── HTTP callout ─────────────────────────────────────────────────────────

    @TestVisible
    private static PelayoIncidentOutBoundStructure.IncidentResponse callIncidentService(
        String endpoint,
        String token,
        String requestBody
    ) {
        PelayoIncidentOutBoundStructure.IncidentResponse serviceResponse =
            new PelayoIncidentOutBoundStructure.IncidentResponse();

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

            System.debug('PelayoIncidentService request body: ' + requestBody);

            Http http = new Http();
            HttpResponse response = http.send(request);

            System.debug('PelayoIncidentService response: ' + response.getBody());

            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                serviceResponse = (PelayoIncidentOutBoundStructure.IncidentResponse)
                    JSON.deserialize(
                        response.getBody(),
                        PelayoIncidentOutBoundStructure.IncidentResponse.class
                    );
            } else {
                serviceResponse.success = false;
                serviceResponse.message =
                    'Failed to send incident to Pelayo service. Status Code: '
                    + response.getStatusCode();
                serviceResponse.errors = response.getBody();
            }
        } catch (Exception e) {
            serviceResponse.success = false;
            serviceResponse.message =
                'Exception while calling Pelayo incident service: ' + e.getMessage();
        }

        return serviceResponse;
    }

    // ─── Event publishing ─────────────────────────────────────────────────────

    private static void sendResponseEvent(Id incidentId, PelayoIncidentOutBoundStructure.IncidentResponse resp) {
        try {
            Boolean ok  = resp != null && resp.success == true;
            String  msg = resp != null ? resp.message : null;
            PelayoWebServiceController.sendResponseEvent(ok, String.valueOf(incidentId), msg);
        } catch (Exception e) {
            // Ignore event publish errors; do not fail the integration.
        }
    }

    // ─── Queueable classes ────────────────────────────────────────────────────

    public class CreateIncidentQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> incidentIds;

        public CreateIncidentQueueable(List<Id> incidentIds) {
            this.incidentIds = incidentIds;
        }

        public void execute(QueueableContext context) {
            if (Test.isRunningTest() && !enableCalloutsInTests) {
                return;
            }
            callCreateIncidentsSync(incidentIds);
        }
    }

    public class UpdateIncidentQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> incidentIds;

        public UpdateIncidentQueueable(List<Id> incidentIds) {
            this.incidentIds = incidentIds;
        }

        public void execute(QueueableContext context) {
            if (Test.isRunningTest() && !enableCalloutsInTests) {
                return;
            }
            callUpdateIncidentsSync(incidentIds);
        }
    }
}