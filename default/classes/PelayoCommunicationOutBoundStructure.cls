/**
 * @description       : Outbound structure and JSON builder for the Pelayo communications integration.
 *                      Builds the payload to notify Pelayo when an SMS is sent from ELBA.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 01-04-2026
 * @last modified by  : Daniel Flores
**/
public class PelayoCommunicationOutBoundStructure {

    public class EmailCommunicationContext {
        public String idSiniestroElba;
        public String idSiniestroAseguradora;
        public String idEncargoElba;
        public String idEncargoAseguradora;
        public String idComunicacionElba;
        public String tipoDestinatario;
        public String nombreDestinatario;
        public String fechaAlta;
        public String usuarioAlta;
        public String fromAddress;
        public String toAddress;
        public String ccAddress;
        public String bccAddress;
        public String subject;
        public String body;
        public List<String> attachmentDocumentIds;

        public EmailCommunicationContext() {
            this.attachmentDocumentIds = new List<String>();
        }
    }

    // ─── Request structures ──────────────────────────────────────────────────

    public class CommunicationRequest {
        public String idSiniestroElba;
        public String idSiniestroAseguradora;
        public String idEncargoElba;
        public String idEncargoAseguradora;
        public String  idComunicacionElba;
        public String  tipoComunicacion;
        public String  tipoDestinatario;
        public String  nombreDestinatario;
        public String  fechaAlta;
        public String  usuarioAlta;
        public Contenido contenido;
    }

    public class Contenido {
        public Movil movil;
        public Correo correo;
    }

    public class Movil {
        public String telefono;
        public String mensaje;
    }

    public class Correo {
        public String fromAddress;
        public String toAddress;
        public String ccAddress;
        public String bccAddress;
        public String subject;
        public String body;
        public List<Adjunto> adjuntos;
    }

    public class Adjunto {
        public String idDocumentoElba;
    }

    // ─── Response structure ──────────────────────────────────────────────────

    public class CommunicationResponse {
        public String  id;
        public Boolean success;
        public String  message;
        public String  errors;
        public String  idSiniestroElba;
        public String  idSiniestroAseguradora;

        public CommunicationResponse() {
            this.success = false;
        }

        public CommunicationResponse(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }

    // ─── JSON builder ────────────────────────────────────────────────────────

    /**
     * @description Builds the JSON payload for the Pelayo communications endpoint.
     * @author Daniel Flores | 01-04-2026
     * @param caseId           Id of the Case (siniestro)
     * @param commentId        Id of the Comments__c record (used as idComunicacionElba)
     * @param phoneNumber      Destination phone number
     * @param textMessage      SMS message content
     * @param recipientType    Recipient selected in the SMS action
     * @return String          Serialised JSON payload
     **/
    public static String createJSON(Id caseId, Id commentId, String phoneNumber, String textMessage, String recipientType) {
        if (caseId == null) {
            return null;
        }

        Case c = [
            SELECT Id, CaseNumber, InsurerClaimReference__c, Contact.Name
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        Map<String, Object> requestBody = new Map<String, Object>{
            'idSiniestroElba' => c.CaseNumber,
            'idSiniestroAseguradora' => c.InsurerClaimReference__c,
            'idEncargoElba' => null,
            'idEncargoAseguradora' => null,
            'idComunicacionElba' => commentId != null ? String.valueOf(commentId) : null,
            'tipoComunicacion' => 'SMS',
            'tipoDestinatario' => recipientType,
            'nombreDestinatario' => recipientType == 'AS' && c.Contact != null ? c.Contact.Name : null,
            'fechaAlta' => Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss'),
            'usuarioAlta' => UserInfo.getName(),
            'contenido' => new Map<String, Object>{
                'movil' => new Map<String, Object>{
                    'telefono' => phoneNumber,
                    'mensaje' => textMessage
                }
            }
        };

        return JSON.serialize(requestBody);
    }

    /**
     * @description Builds the JSON payload for an email communication sent to Pelayo.
     * @author Daniel Flores | 01-04-2026
     * @param context Email communication context already resolved by the service layer
     * @return String Serialised JSON payload
     **/
    public static String createEmailJSON(EmailCommunicationContext context) {
        if (context == null || String.isBlank(context.idSiniestroElba)) {
            return null;
        }

        Map<String, Object> requestBody = new Map<String, Object>{
            'idSiniestroElba' => context.idSiniestroElba,
            'idSiniestroAseguradora' => context.idSiniestroAseguradora,
            'idEncargoElba' => context.idEncargoElba,
            'idEncargoAseguradora' => context.idEncargoAseguradora,
            'idComunicacionElba' => context.idComunicacionElba,
            'tipoComunicacion' => 'EML',
            'tipoDestinatario' => context.tipoDestinatario,
            'nombreDestinatario' => context.nombreDestinatario,
            'fechaAlta' => context.fechaAlta,
            'usuarioAlta' => context.usuarioAlta
        };

        List<Object> attachments = new List<Object>();
        if (context.attachmentDocumentIds != null) {
            for (String documentId : context.attachmentDocumentIds) {
                if (String.isBlank(documentId)) {
                    continue;
                }
                attachments.add(new Map<String, Object>{
                    'idDocumentoElba' => documentId
                });
            }
        }

        Map<String, Object> correo = new Map<String, Object>{
            'from' => context.fromAddress,
            'to' => context.toAddress,
            'cc' => context.ccAddress,
            'bcc' => context.bccAddress,
            'asunto' => context.subject,
            'cuerpo' => context.body,
            'adjuntos' => attachments
        };

        requestBody.put('contenido', new Map<String, Object>{
            'correo' => correo
        });

        return JSON.serialize(requestBody);
    }
}