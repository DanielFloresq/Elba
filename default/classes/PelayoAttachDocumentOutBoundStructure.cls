/**
 * @description       : Outbound structure and JSON builder for the Pelayo attachDocument integration.
 *                      Each file requires a separate API call, so the builder returns one payload
 *                      per ContentVersion / FileAttachmentInput entry.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 02-04-2026
 * @last modified by  : Daniel Flores
**/
public class PelayoAttachDocumentOutBoundStructure {

    // ─── Request / Response structures ───────────────────────────────────────

    public class AttachDocumentRequest {
        public String  idSiniestroElba;
        public String  idSiniestroAseguradora;
        public EncargoRef encargo;
        public Documento documento;
    }

    public class EncargoRef {
        public String idEncargoElba;
        public String idEncargoAseguradora;
        public String idServicio;
    }

    public class Documento {
        public String  idDocumentoElba;
        public String  familia;
        public String  tipo;
        public String  nombre;
        public String  descripcion;
        public Boolean eliminable;
        public String  fechaAlta;
        public String  usuarioAlta;
        public String  fechaModificacion;
        public String  usuarioModificacion;
        public String  contenidoBase64;
    }

    public class AttachDocumentResponse {
        public String  id;
        public Boolean success;
        public String  message;
        public String  errors;
        public String  idSiniestroElba;
        public String  idSiniestroAseguradora;
        public String  idDocumentoElba;
        public String  detail;
    }

    /**
     * @description DTO used by callers (e.g. LWC controller) to pass file metadata
     *              that cannot be derived from ContentVersion alone (familiaDoc / tipoDoc
     *              are chosen by the user in the component).
     */
    public class FileAttachmentInput {
        @AuraEnabled public Id     contentVersionId;
        @AuraEnabled public String familiaDoc;
        @AuraEnabled public String tipoDoc;
        @AuraEnabled public String descripcionDoc;   // optional — falls back to ContentVersion.Description
        @AuraEnabled public Boolean eliminaDoc;       // optional — defaults to false

        public FileAttachmentInput() {
            this.eliminaDoc = false;
        }
    }

    // ─── JSON builder ────────────────────────────────────────────────────────

    /**
     * @description Builds one JSON payload per FileAttachmentInput entry.
     *              Multiple inputs → multiple payloads → multiple API calls.
     * @author Daniel Flores | 16-03-2026
     * @param caseId    Id of the Case (siniestro)
     * @param orderId   Id of the Order (encargo) — may be null if not applicable
     * @param inputs    List of file inputs (one per document to send)
     * @return List<String>  Ordered list of serialised JSON payloads
     **/
    public static List<String> createJSONPayloads(Id caseId, Id orderId, List<FileAttachmentInput> inputs) {
        List<String> out = new List<String>();
        if (caseId == null || inputs == null || inputs.isEmpty()) {
            return out;
        }
 
        // ── Fetch Case ──────────────────────────────────────────────────────
        Case c = [
            SELECT Id, CaseNumber, InsurerClaimReference__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        // ── Collect ContentVersion ids from inputs ───────────────────────────
        Set<Id> cvIds = new Set<Id>();
        for (FileAttachmentInput inp : inputs) {
            if (inp != null && inp.contentVersionId != null) {
                cvIds.add(inp.contentVersionId);
            }
        }

        Map<Id, ContentVersion> cvById = new Map<Id, ContentVersion>([
            SELECT
                Id,
                ContentDocumentId,
                Title,
                PathOnClient,
                Description,
                VersionData,
                CreatedDate,
                CreatedBy.Name,
                LastModifiedDate,
                LastModifiedBy.Name
            FROM ContentVersion
            WHERE Id IN :cvIds
        ]);

        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentVersion cv : cvById.values()) {
            if (cv.ContentDocumentId != null) {
                contentDocumentIds.add(cv.ContentDocumentId);
            }
        }

        Map<Id, Id> inferredOrderIdByDocumentId = inferOrderIdByDocumentId(contentDocumentIds);

        Set<Id> orderIdsToQuery = new Set<Id>();
        if (orderId != null) {
            orderIdsToQuery.add(orderId);
        }
        orderIdsToQuery.addAll(inferredOrderIdByDocumentId.values());

        Map<Id, Order> ordersById = orderIdsToQuery.isEmpty()
            ? new Map<Id, Order>()
            : new Map<Id, Order>([
                SELECT Id, OrderNumber, ChargeIdentifier__c
                FROM Order
                WHERE Id IN :orderIdsToQuery
            ]);

        Map<Id, String> serviceIdByOrderId = inferServiceIdByOrderId(orderIdsToQuery);

        // ── Build one payload per input ──────────────────────────────────────
        for (FileAttachmentInput inp : inputs) {
            if (inp == null || inp.contentVersionId == null) {
                continue;
            }
            ContentVersion cv = cvById.get(inp.contentVersionId);
            if (cv == null) {
                continue;
            }

            Order resolvedOrder = orderId != null ? ordersById.get(orderId) : null;
            if (resolvedOrder == null && cv.ContentDocumentId != null) {
                Id inferredOrderId = inferredOrderIdByDocumentId.get(cv.ContentDocumentId);
                if (inferredOrderId != null) {
                    resolvedOrder = ordersById.get(inferredOrderId);
                }
            }

            String resolvedServiceId = resolvedOrder != null
                ? serviceIdByOrderId.get(resolvedOrder.Id)
                : null;

            AttachDocumentRequest req = buildRequest(
                c,
                resolvedOrder,
                resolvedServiceId,
                cv,
                inp
            );
            out.add(serializeRequest(req));
        }

        return out;
    }

    // ─── Internal helpers ─────────────────────────────────────────────────────

    /**
     * @description Builds a single AttachDocumentRequest, combining Salesforce record
     *              data with the component-supplied metadata (familiaDoc / tipoDoc).
     * @author Daniel Flores | 16-03-2026
     **/
    @TestVisible
    static AttachDocumentRequest buildRequest(
        Case             c,
        Order            ord,
        String           serviceId,
        ContentVersion   cv,
        FileAttachmentInput inp
    ) {
        AttachDocumentRequest req = new AttachDocumentRequest();
        Documento doc = new Documento();

        req.idSiniestroElba          = c.CaseNumber;
        req.idSiniestroAseguradora   = c.InsurerClaimReference__c;

        if (ord != null) {
            EncargoRef enc         = new EncargoRef();
            enc.idEncargoElba      = ord.OrderNumber;
            enc.idEncargoAseguradora = ord.ChargeIdentifier__c;
            enc.idServicio         = serviceId;
            req.encargo            = enc;
        }

        // idDocumentoElba: using the ContentDocument Id as the ELBA document identifier.
        // Replace with a custom field (e.g. ContentDocument.ElbaDocumentId__c) if available.
        doc.idDocumentoElba = String.valueOf(cv.ContentDocumentId);

        doc.familia   = inp.familiaDoc;
        doc.tipo      = inp.tipoDoc;

        // File name: prefer PathOnClient (includes extension); fall back to Title
        doc.nombre    = normaliseFileName(
            String.isNotBlank(cv.PathOnClient) ? cv.PathOnClient : cv.Title
        );

        // Description: prefer value supplied by component; fall back to ContentVersion.Description
        doc.descripcion = String.isNotBlank(inp.descripcionDoc)
            ? inp.descripcionDoc
            : cv.Description;

        doc.eliminable = (inp.eliminaDoc != null) ? inp.eliminaDoc : false;

        // fechaAlta ISO-8601 without timezone offset (format expected by Pelayo)
        doc.fechaAlta  = cv.CreatedDate != null
            ? cv.CreatedDate.format('yyyy-MM-dd\'T\'HH:mm:ss')
            : null;

        doc.usuarioAlta    = cv.CreatedBy != null ? cv.CreatedBy.Name : null;
        doc.fechaModificacion = cv.LastModifiedDate != null
            ? cv.LastModifiedDate.format('yyyy-MM-dd\'T\'HH:mm:ss')
            : null;
        doc.usuarioModificacion = cv.LastModifiedBy != null ? cv.LastModifiedBy.Name : null;
        doc.contenidoBase64 = cv.VersionData != null
            ? EncodingUtil.base64Encode(cv.VersionData)
            : null;

        req.documento = doc;

        return req;
    }

    /**
     * @description Serialises an AttachDocumentRequest into a JSON string with suppressed null values.
     * @param req AttachDocumentRequest instance to serialise
     * @return String JSON representation of the request
     **/
    @TestVisible
    static String serializeRequest(AttachDocumentRequest req) {
        return JSON.serialize(req, true);
    }

    /**
     * @description Normalises a file name by stripping any directory path prefix and removing spaces before file extensions.
     * @param rawName Raw file name or path string
     * @return String Cleaned file name, or the original value if blank
     **/
    @TestVisible
    static String normaliseFileName(String rawName) {
        if (String.isBlank(rawName)) {
            return rawName;
        }

        String fileName = rawName.trim();
        Integer lastForwardSlash = fileName.lastIndexOf('/');
        Integer lastBackSlash = fileName.lastIndexOf('\\');
        Integer lastSeparator = Math.max(lastForwardSlash, lastBackSlash);
        if (lastSeparator >= 0 && lastSeparator < fileName.length() - 1) {
            fileName = fileName.substring(lastSeparator + 1).trim();
        }

        return fileName.replaceAll('\\s+\\.', '.');
    }

    /**
     * @description Infers the related Order Id for each ContentDocument by inspecting ContentDocumentLink records.
     *              Only returns a mapping when a ContentDocument is linked to exactly one Order.
     * @param contentDocumentIds Set of ContentDocument Ids to look up
     * @return Map<Id, Id> Map of ContentDocumentId to the single linked Order Id
     **/
    private static Map<Id, Id> inferOrderIdByDocumentId(Set<Id> contentDocumentIds) {
        Map<Id, Id> inferredOrderIdByDocumentId = new Map<Id, Id>();
        if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            return inferredOrderIdByDocumentId;
        }

        String orderPrefix = Order.SObjectType.getDescribe().getKeyPrefix();
        Map<Id, Set<Id>> orderIdsByDocumentId = new Map<Id, Set<Id>>();

        for (ContentDocumentLink link : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :contentDocumentIds
        ]) {
            if (link.LinkedEntityId == null
                || !String.valueOf(link.LinkedEntityId).startsWith(orderPrefix)) {
                continue;
            }

            if (!orderIdsByDocumentId.containsKey(link.ContentDocumentId)) {
                orderIdsByDocumentId.put(link.ContentDocumentId, new Set<Id>());
            }
            orderIdsByDocumentId.get(link.ContentDocumentId).add(link.LinkedEntityId);
        }

        for (Id contentDocumentId : orderIdsByDocumentId.keySet()) {
            Set<Id> linkedOrderIds = orderIdsByDocumentId.get(contentDocumentId);
            if (linkedOrderIds != null && linkedOrderIds.size() == 1) {
                inferredOrderIdByDocumentId.put(
                    contentDocumentId,
                    new List<Id>(linkedOrderIds)[0]
                );
            }
        }

        return inferredOrderIdByDocumentId;
    }

    /**
     * @description Infers the Service Name (idServicio) for each Order by querying Service__c records.
     *              Only returns a mapping when an Order has exactly one related Service.
     * @param orderIds Set of Order Ids to look up
     * @return Map<Id, String> Map of Order Id to the single Service Name
     **/
    private static Map<Id, String> inferServiceIdByOrderId(Set<Id> orderIds) {
        Map<Id, String> inferredServiceIdByOrderId = new Map<Id, String>();
        if (orderIds == null || orderIds.isEmpty()) {
            return inferredServiceIdByOrderId;
        }

        Map<Id, Set<String>> serviceIdsByOrderId = new Map<Id, Set<String>>();

        for (Service__c serviceRecord : [
            SELECT Id, Name, Order__c
            FROM Service__c
            WHERE Order__c IN :orderIds
        ]) {
            if (serviceRecord.Order__c == null || String.isBlank(serviceRecord.Name)) {
                continue;
            }

            if (!serviceIdsByOrderId.containsKey(serviceRecord.Order__c)) {
                serviceIdsByOrderId.put(serviceRecord.Order__c, new Set<String>());
            }
            serviceIdsByOrderId.get(serviceRecord.Order__c).add(serviceRecord.Name);
        }

        for (Id currentOrderId : serviceIdsByOrderId.keySet()) {
            Set<String> currentServiceIds = serviceIdsByOrderId.get(currentOrderId);
            if (currentServiceIds != null && currentServiceIds.size() == 1) {
                inferredServiceIdByOrderId.put(
                    currentOrderId,
                    new List<String>(currentServiceIds)[0]
                );
            }
        }

        return inferredServiceIdByOrderId;
    }
}