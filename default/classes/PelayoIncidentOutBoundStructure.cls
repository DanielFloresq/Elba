/**
 * @description       : Outbound structure and JSON builder for the Pelayo createIncident integration.
 *                      Builds the payload to notify Pelayo when an Incident is created from ELBA.
 * @author            : Daniel Flores
 * @group             : Pelayo Integration
 * @last modified on  : 06-04-2026
 * @last modified by  : Daniel Flores
**/
public class PelayoIncidentOutBoundStructure {

    private static final String MOVIMIENTO_ALTA = 'AL';
    private static final String MOVIMIENTO_MODIFICACION = 'MO';

    // ─── Request structures ──────────────────────────────────────────────────

    public class IncidentRequest {
        public String idSiniestroElba;
        public String idSiniestroAseguradora;
        public String movimiento;
        public String idIncidenciaElba;
        public String idEncargoElba;
        public String idServicioElba;
        public String tipo;
        public String motivo;
        public String submotivo;
        public String origen;
        public String canal;
        public String equipoGestion;
        public String responsableIncidencias;
        public String tipoCausante;
        public String causante;
        public String estado;
        public String fechaEstado;
        public String descripcion;
        public String fechaGrabacion;
        public String fechaAlta;
        public String usuarioAlta;
        public Comentario comentario;
    }

    public class Comentario {
        public String idComentarioElba;
        public String descripcion;
    }

    // ─── Response structure ──────────────────────────────────────────────────

    public class IncidentResponse {
        public String  id;
        public Boolean success;
        public String  message;
        public String  errors;
        public String  idSiniestroElba;
        public String  idSiniestroAseguradora;
        public String  idIncidenciaElba;
        public String  idIncidenciaAseguradora;

        public IncidentResponse() {
            this.success = false;
        }

        public IncidentResponse(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }

    // ─── Context structure for building request ──────────────────────────────

    public class IncidentContext {
        public Id incidentId;
        public String idSiniestroElba;
        public String idSiniestroAseguradora;
        public String idEncargoElba;
        public String idServicioElba;
        public String idIncidenciaElba;
        public String tipo;
        public String motivo;
        public String submotivo;
        public String origen;
        public String canal;
        public String equipoGestion;
        public String responsableIncidencias;
        public String tipoCausante;
        public String causante;
        public String estado;
        public Datetime fechaEstado;
        public String descripcion;
        public Datetime fechaGrabacion;
        public Datetime fechaAlta;
        public String usuarioAlta;
        public String comentarioId;
        public String comentarioDescripcion;
    }

    // ─── JSON builder ────────────────────────────────────────────────────────

    /**
     * @description Builds the JSON payload for the Pelayo createIncident endpoint.
     * @author Daniel Flores | 06-04-2026
     * @param context IncidentContext with all required data
     * @return String Serialised JSON payload
     **/
    public static String createJSON(IncidentContext context) {
        return buildJSON(context, MOVIMIENTO_ALTA);
    }

    /**
     * @description Builds the JSON payload for updating an incident (movimiento = MO).
     * @author Daniel Flores | 06-04-2026
     * @param context IncidentContext with all required data
     * @return String Serialised JSON payload
     **/
    public static String createUpdateJSON(IncidentContext context) {
        return buildJSON(context, MOVIMIENTO_MODIFICACION);
    }

    private static String buildJSON(IncidentContext context, String movimiento) {
        if (context == null || String.isBlank(context.idSiniestroElba)) {
            return null;
        }

        IncidentRequest req = new IncidentRequest();
        req.idSiniestroElba        = context.idSiniestroElba;
        req.idSiniestroAseguradora = context.idSiniestroAseguradora;
        req.movimiento             = movimiento;
        req.idIncidenciaElba       = context.idIncidenciaElba;
        req.idEncargoElba          = context.idEncargoElba;
        req.idServicioElba         = context.idServicioElba;
        req.tipo                   = context.tipo;
        req.motivo                 = context.motivo;
        req.submotivo              = context.submotivo;
        req.origen                 = context.origen;
        req.canal                  = context.canal;
        req.equipoGestion          = context.equipoGestion;
        req.responsableIncidencias = context.responsableIncidencias;
        req.tipoCausante           = context.tipoCausante;
        req.causante               = context.causante;
        req.estado                 = context.estado;
        req.fechaEstado            = formatDatetime(context.fechaEstado);
        req.descripcion            = context.descripcion;
        req.fechaGrabacion         = formatDatetime(context.fechaGrabacion);
        req.fechaAlta              = formatDatetime(context.fechaAlta);
        req.usuarioAlta            = context.usuarioAlta;

        // Add comment if available
        if (String.isNotBlank(context.comentarioId) || String.isNotBlank(context.comentarioDescripcion)) {
            Comentario com = new Comentario();
            com.idComentarioElba = context.comentarioId;
            com.descripcion      = context.comentarioDescripcion;
            req.comentario       = com;
        }

        return JSON.serialize(req);
    }

    // ─── Helper methods ──────────────────────────────────────────────────────

    private static String formatDatetime(Datetime dt) {
        if (dt == null) {
            return null;
        }
        return dt.format('yyyy-MM-dd\'T\'HH:mm:ss');
    }

    /**
     * @description Maps Salesforce Incident Status to Pelayo estado code.
     * @author Daniel Flores | 06-04-2026
     * @param status Salesforce Incident Status
     * @return String Pelayo estado code (AB=Abierto, CE=Cerrado)
     **/
    public static String mapStatusToEstado(String status) {
        if (String.isBlank(status)) {
            return 'AB';
        }
        String normalized = status.toLowerCase();
        if (normalized.contains('closed') || normalized.contains('resolved') || normalized.contains('cerrado')) {
            return 'CE';
        }
        return 'AB';
    }

    /**
     * @description Maps Salesforce Incident Type to Pelayo tipo code.
     * @author Daniel Flores | 06-04-2026
     * @param incidentType Salesforce Incident Type field value
     * @return String Pelayo tipo code
     **/
    public static String mapTypeToPelayo(String incidentType) {
        if (String.isBlank(incidentType)) {
            return null;
        }
        // Map based on Incident Type values
        // DI = Dissatisfaction, RE = Claim, QU = Complaint, SU = Suggestion, CO = Consultation
        Map<String, String> typeMapping = new Map<String, String>{
            'Dissatisfaction' => 'DI',
            'Claim'           => 'RE',
            'Complaint'       => 'QU',
            'Suggestion'      => 'SU',
            'Consultation'    => 'CO'
        };
        return typeMapping.containsKey(incidentType) ? typeMapping.get(incidentType) : incidentType;
    }
}