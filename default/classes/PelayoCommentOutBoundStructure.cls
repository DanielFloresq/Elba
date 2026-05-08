/**
 * @description       : Outbound structure and JSON builder for the Pelayo createComment integration.
 *                      Builds the payload to notify Pelayo when a Comment with "Hito - " subject is created.
 * @author            : Daniel Flores
 * @group             : Pelayo Integration
 * @last modified on  : 06-04-2026
 * @last modified by  : Daniel Flores
**/
public class PelayoCommentOutBoundStructure {

    // ─── Request structures ──────────────────────────────────────────────────

    public class CommentRequest {
        public String idSiniestroElba;
        public String idSiniestroAseguradora;
        public String idEncargoElba;
        public String idEncargoAseguradora;
        public String idComentarioElba;
        public Destinatario destinatario;
        public Detalle detalle;
    }

    public class Destinatario {
        public String tipoDestinatario;
        public String identificador;
        public String nombre;
    }

    public class Detalle {
        public String autor;
        public String titulo;
        public String mensaje;
        public String fechaCreacion;
        public Boolean privado;
        public String fechaAlta;
        public String usuarioAlta;
        public String fechaModificacion;
        public String usuarioModificacion;
    }

    // ─── Response structure ──────────────────────────────────────────────────

    public class CommentResponse {
        public String  id;
        public Boolean success;
        public String  message;
        public String  errors;
        public String  idSiniestroElba;
        public String  idSiniestroAseguradora;
        public String  idComentarioElba;

        public CommentResponse() {
            this.success = false;
        }

        public CommentResponse(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }

    // ─── Context structure for building request ──────────────────────────────

    public class CommentContext {
        public Id commentId;
        public String idSiniestroElba;
        public String idSiniestroAseguradora;
        public String idEncargoElba;
        public String idEncargoAseguradora;
        public String idComentarioElba;
        public String tipoDestinatario;
        public String identificadorDestinatario;
        public String nombreDestinatario;
        public String autor;
        public String titulo;
        public String mensaje;
        public Datetime fechaCreacion;
        public Boolean privado;
        public Datetime fechaAlta;
        public String usuarioAlta;
        public Datetime fechaModificacion;
        public String usuarioModificacion;
    }

    // ─── JSON builder ────────────────────────────────────────────────────────

    /**
     * @description Builds the JSON payload for the Pelayo createComment endpoint.
     * @author Daniel Flores | 06-04-2026
     * @param context CommentContext with all required data
     * @return String Serialised JSON payload
     **/
    public static String createJSON(CommentContext context) {
        if (context == null || String.isBlank(context.idSiniestroElba)) {
            return null;
        }

        CommentRequest req = new CommentRequest();
        req.idSiniestroElba        = context.idSiniestroElba;
        req.idSiniestroAseguradora = context.idSiniestroAseguradora;
        req.idEncargoElba          = context.idEncargoElba;
        req.idEncargoAseguradora   = context.idEncargoAseguradora;
        req.idComentarioElba       = context.idComentarioElba;

        // Destinatario
        Destinatario dest = new Destinatario();
        dest.tipoDestinatario = context.tipoDestinatario;
        dest.identificador    = context.identificadorDestinatario;
        dest.nombre           = context.nombreDestinatario;
        req.destinatario      = dest;

        // Detalle
        Detalle det = new Detalle();
        det.autor              = context.autor;
        det.titulo             = context.titulo;
        det.mensaje            = context.mensaje;
        det.fechaCreacion      = formatDatetime(context.fechaCreacion);
        det.privado            = context.privado != null ? context.privado : false;
        det.fechaAlta          = formatDatetime(context.fechaAlta);
        det.usuarioAlta        = context.usuarioAlta;
        det.fechaModificacion  = formatDatetime(context.fechaModificacion);
        det.usuarioModificacion = context.usuarioModificacion;
        req.detalle            = det;

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
     * @description Maps the recipient type based on Comment relations.
     * @author Daniel Flores | 06-04-2026
     * @param hasOrder Whether the comment is related to an Order
     * @param hasStakeholder Whether the comment has a Stakeholder
     * @return String Pelayo tipo destinatario code
     **/
    public static String mapTipoDestinatario(Boolean hasOrder, Boolean hasStakeholder) {
        if (hasOrder) {
            return 'PROVEEDOR';
        }
        if (hasStakeholder) {
            return 'IMPLICADO';
        }
        return 'ASEGURADO';
    }
}