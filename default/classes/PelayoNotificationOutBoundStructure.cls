/**
 * @description       : Outbound structure and JSON builder for the Pelayo createNotification integration.
 *                      Builds the payload to notify Pelayo when a Solicitation is created in ELBA.
 * @author            : Daniel Flores
 * @group             : Pelayo Integration
 * @last modified on  : 07-04-2026
 * @last modified by  : Daniel Flores
**/
public class PelayoNotificationOutBoundStructure {

    public class NotificationRequest {
        public String idSiniestroElba;
        public String idSiniestroAseguradora;
        public String movimiento;
        public String idNotificacionElba;
        public String idNotificacionAseguradora;
        public String idEncargoElba;
        public String tipoSolicitudElba;
        public String descripcion;
        public String fechaAlta;
        public String usuarioAlta;
        public String fechaModificacion;
        public String usuarioModificacion;
    }

    public class NotificationResponse {
        public String id;
        public Boolean success;
        public String message;
        public String errors;
        public String idSiniestroElba;
        public String idNotificacionElba;

        public NotificationResponse() {
            this.success = false;
        }

        public NotificationResponse(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }

    public class NotificationContext {
        public Id solicitationId;
        public String idSiniestroElba;
        public String idSiniestroAseguradora;
        public String idNotificacionElba;
        public String idNotificacionAseguradora;
        public String idEncargoElba;
        public String tipoSolicitudElba;
        public String descripcion;
        public Datetime fechaAlta;
        public String usuarioAlta;
        public Datetime fechaModificacion;
        public String usuarioModificacion;
    }

    public static String createJSON(NotificationContext context) {
        if (context == null || String.isBlank(context.idSiniestroElba)) {
            return null;
        }

        NotificationRequest req = new NotificationRequest();
        req.idSiniestroElba = context.idSiniestroElba;
        req.idSiniestroAseguradora = context.idSiniestroAseguradora;
        req.movimiento = 'AL';
        req.idNotificacionElba = context.idNotificacionElba;
        req.idNotificacionAseguradora = context.idNotificacionAseguradora;
        req.idEncargoElba = context.idEncargoElba;
        req.tipoSolicitudElba = context.tipoSolicitudElba;
        req.descripcion = context.descripcion;
        req.fechaAlta = formatDatetime(context.fechaAlta);
        req.usuarioAlta = context.usuarioAlta;
        req.fechaModificacion = formatDatetime(context.fechaModificacion);
        req.usuarioModificacion = context.usuarioModificacion;

        return JSON.serialize(req);
    }

    private static String formatDatetime(Datetime dt) {
        if (dt == null) {
            return null;
        }
        return dt.format('yyyy-MM-dd\'T\'HH:mm:ss');
    }
}