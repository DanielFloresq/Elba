/**
 * @description       : Controller for uploading and managing documents attached to case records
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 05-05-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class CaseDocumentUploaderController {

    
    public class FileWrapper {
        @AuraEnabled public String fileName { get; set; }
        @AuraEnabled public String base64Data{ get; set; }
    }

    private class PelayoUploadContext {
        public Id caseId;
        public Id orderId;
    }

    private static final String PELAYO_ACCOUNT_CODE = 'PLYO';

    /**
     * @description Uploads files as ContentVersions and links them to a Case and optionally another entity, then enqueues Pelayo attachment if applicable
     * @param caseId ID of the Case to link documents to
     * @param tipoDocumental Document type classification
     * @param description Description for the uploaded documents
     * @param files List of FileWrapper objects containing file name and base64 data
     * @param linkedEntityId Optional secondary entity ID to link documents to
     * @param faseDocumental Document phase classification
     */
    @AuraEnabled
    public static void uploadDocuments(
        Id caseId,
        String tipoDocumental,
        String description,
        List<FileWrapper> files,
        Id linkedEntityId,
        String faseDocumental
    ) {
        if (caseId == null || files == null || files.isEmpty()) {
            return;
        }

        List<ContentVersion> versions = new List<ContentVersion>();

        // Criar ContentVersions a partir dos ficheiros recebidos
        for (FileWrapper f : files) {
            if (String.isBlank(f.fileName) || String.isBlank(f.base64Data)) {
                System.debug('Ignorado: ' + f.fileName + ', base64Data null ou vazio');
                continue;
            }

            try {
                ContentVersion cv = new ContentVersion();
                cv.Title = f.fileName;
                cv.PathOnClient = f.fileName;
                cv.VersionData = EncodingUtil.base64Decode(f.base64Data);
                cv.Description = description;
                cv.DocumentType__c = tipoDocumental;
                cv.DocumentPhase__c = faseDocumental;

                versions.add(cv);
            } catch(Exception e) {
                System.debug('Erro ao decodificar ficheiro ' + f.fileName + ': ' + e.getMessage());
            }
        }

        if (versions.isEmpty()) {
            return;
        }

        // Inserir ContentVersions
        insert versions;

        // Buscar ContentDocumentId + Id atualizado após insert
        versions = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :versions];

        // Criar links para o Case
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (ContentVersion cv : versions) {
            links.add(new ContentDocumentLink(
                LinkedEntityId = caseId,
                ContentDocumentId = cv.ContentDocumentId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
            if (linkedEntityId != null && linkedEntityId != caseId) {
                links.add(new ContentDocumentLink(
                    LinkedEntityId = linkedEntityId,
                    ContentDocumentId = cv.ContentDocumentId,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                ));
            }
        }

        // Inserir links
        if (!links.isEmpty()) {
            insert links;
        }

        // ── Enviar para Pelayo (Cases Pelayo e Orders com Case Pelayo relacionado) ──
        enqueuePelayoAttach(caseId, linkedEntityId, versions, faseDocumental, tipoDocumental, description);
    }

    /**
     * @description Enqueues document submission to the Pelayo attachDocument service. Only executes if the Case belongs to the Pelayo company (GrandAccount__c = 'PLYO'). Called after file upload to ensure ContentVersions are registered before making the HTTP call.
     * @param recordId ID of the primary record (Case or Order)
     * @param linkedEntityId ID of the secondary linked entity
     * @param versions List of ContentVersion records to send
     * @param faseDocumental Document phase classification
     * @param tipoDocumental Document type classification
     * @param description Description of the documents
     */
    private static void enqueuePelayoAttach(
        Id recordId,
        Id linkedEntityId,
        List<ContentVersion> versions,
        String faseDocumental,
        String tipoDocumental,
        String description
    ) {
        try {
            PelayoUploadContext context = resolvePelayoUploadContext(recordId, linkedEntityId);
            if (context == null || context.caseId == null) {
                return;
            }

            List<Case> cases = [SELECT GrandAccount__c FROM Case WHERE Id = :context.caseId LIMIT 1];
            if (cases.isEmpty() || cases[0].GrandAccount__c != PELAYO_ACCOUNT_CODE) {
                return;
            }

            List<PelayoAttachDocumentOutBoundStructure.FileAttachmentInput> inputs =
                new List<PelayoAttachDocumentOutBoundStructure.FileAttachmentInput>();

            for (ContentVersion cv : versions) {
                PelayoAttachDocumentOutBoundStructure.FileAttachmentInput fi =
                    new PelayoAttachDocumentOutBoundStructure.FileAttachmentInput();
                fi.contentVersionId = cv.Id;
                fi.familiaDoc       = faseDocumental;   // DocumentPhase__c → familiaDoc
                fi.tipoDoc          = tipoDocumental;   // DocumentType__c   → tipoDoc
                fi.descripcionDoc   = description;
                fi.eliminaDoc       = false;
                inputs.add(fi);
            }

            PelayoAttachDocumentService.enqueue(context.caseId, context.orderId, inputs);
        } catch (Exception e) {
            // Não falhar o upload por causa de erro no envio Pelayo
            System.debug(LoggingLevel.ERROR,
                'CaseDocumentUploaderController.enqueuePelayoAttach error: ' + e.getMessage());
        }
    }

    /**
     * @description Resolves the Pelayo upload context by determining the Case and Order IDs from the given record and linked entity
     * @param recordId ID of the primary record
     * @param linkedEntityId ID of the secondary linked entity
     * @return PelayoUploadContext containing the resolved Case and Order IDs
     */
    @TestVisible
    private static PelayoUploadContext resolvePelayoUploadContext(Id recordId, Id linkedEntityId) {
        PelayoUploadContext context = new PelayoUploadContext();
        String casePrefix = Case.SObjectType.getDescribe().getKeyPrefix();
        String orderPrefix = Order.SObjectType.getDescribe().getKeyPrefix();

        if (recordId != null && String.valueOf(recordId).startsWith(casePrefix)) {
            context.caseId = recordId;
        } else if (linkedEntityId != null && String.valueOf(linkedEntityId).startsWith(casePrefix)) {
            context.caseId = linkedEntityId;
        }

        if (recordId != null && String.valueOf(recordId).startsWith(orderPrefix)) {
            context.orderId = recordId;
        } else if (linkedEntityId != null && String.valueOf(linkedEntityId).startsWith(orderPrefix)) {
            context.orderId = linkedEntityId;
        }

        if (context.orderId != null && context.caseId == null) {
            List<Order> orders = [
                SELECT Id, CaseNumber__c
                FROM Order
                WHERE Id = :context.orderId
                LIMIT 1
            ];

            if (!orders.isEmpty()) {
                context.caseId = orders[0].CaseNumber__c;
            }
        }

        return context;
    }

    /**
     * @description Retrieves orders related to a given Case, Order, Contact or Task for display as selectable options
     * @param caseId ID of the record to find related orders for
     * @return List of maps with label and value keys representing available options
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String,String>> getRelatedOrders(String caseId) {
        List<Map<String,String>> options = new List<Map<String,String>>();

        if (caseId.startsWith('500') || caseId.startsWith('801')) {
            if (caseId == null) return options;
            String caseLabel = Case.SObjectType.getDescribe().getLabel();
            String orderLabel = Order.SObjectType.getDescribe().getLabel(); 
            Case c = new Case();
            List<Order> orders = new List<Order>();
            if (caseId.startsWith('500')) {
                c = [SELECT CaseNumber FROM Case WHERE Id = :caseId LIMIT 1];
                options.add(new Map<String,String>{'label' => caseLabel + ' - ' +c.CaseNumber, 'value' => caseId});
                orders = [
                    SELECT Id, Name, OrderNumber
                    FROM Order 
                    WHERE CaseNumber__c = :caseId
                ];
            }else if (caseId.startsWith('801')) {
                orders = [
                    SELECT Id, Name, OrderNumber
                    FROM Order 
                    WHERE Id = :caseId
                ];
            }
        
            for(Order o : orders){
                options.add(new Map<String,String>{'label' =>orderLabel + ' - ' + o.OrderNumber, 'value' => o.Id});
            }
        }else if (caseId.startsWith('003')) {
            String contactLabel = Contact.SObjectType.getDescribe().getLabel();
            Contact c = [SELECT Name FROM Contact WHERE Id = :caseId LIMIT 1];
            options.add(new Map<String,String>{'label' => contactLabel + ' - ' +c.Name, 'value' => caseId});
        }else if (caseId.startsWith('00T')) {
            String taskLabel = Task.SObjectType.getDescribe().getLabel();
            Task t = [SELECT Subject FROM Task WHERE Id = :caseId LIMIT 1];
            options.add(new Map<String,String>{'label' => taskLabel + ' - ' +t.Subject, 'value' => caseId});
        }
        

        return options;
    }

    /**
     * @description Returns the active picklist values for FaseDocumental__c and DocumentType__c fields on ContentVersion
     * @return Map containing picklist options keyed by 'fase' and 'docType'
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getPicklistValues() {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        
        try {
            // Obter valores de FaseDocumental__c
            Schema.DescribeFieldResult faseField = ContentVersion.DocumentPhase__c.getDescribe();
            List<Map<String, String>> faseOptions = new List<Map<String, String>>();
            for (Schema.PicklistEntry entry : faseField.getPicklistValues()) {
                if (entry.isActive()) {
                    faseOptions.add(new Map<String, String>{
                        'label' => entry.getLabel(),
                        'value' => entry.getValue()
                    });
                }
            }
            result.put('fase', faseOptions);
            
            // Obter valores de DocumentType__c
            Schema.DescribeFieldResult docTypeField = ContentVersion.DocumentType__c.getDescribe();
            List<Map<String, String>> docTypeOptions = new List<Map<String, String>>();
            for (Schema.PicklistEntry entry : docTypeField.getPicklistValues()) {
                if (entry.isActive()) {
                    docTypeOptions.add(new Map<String, String>{
                        'label' => entry.getLabel(),
                        'value' => entry.getValue()
                    });
                }
            }
            result.put('docType', docTypeOptions);
            
            System.debug('Picklistss carregados: ' + result);
            return result;
        } catch (Exception e) {
            System.debug('Erro ao obter picklist values: ' + e.getMessage());
            throw new AuraHandledException('Erro ao obter valores: ' + e.getMessage());
        }
    }


}