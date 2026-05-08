/**
 * @description       : Controller for managing chat message comments on order records in ELBA
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 06-05-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class ElbaChatMessageOrderController {

    /**
     * @description Retrieves all comments associated with a given Order, including file attachments and user details
     * @param OrderId The Id of the Order record to retrieve comments for
     * @param UserId The Id of the current User viewing the comments
     * @return List of Comentarios wrapper objects for display, or null if no comments exist
     */
    @AuraEnabled
    public static List<Comentarios> GetComentarios(String OrderId, String UserId ) {
        
        List<Comments__c> Comentarios = [
        SELECT
          Id,
          CreatedDate,
          CreatedById,
          Favorite__c,
          Agent__c,
          Comment__c,
          (
            SELECT
              ID,
              ContentDocumentId,
              ContentDocument.LatestPublishedVersion.Title,
              ContentDocument.LatestPublishedVersion.ReasonForChange,
              ContentDocument.LatestPublishedVersion.IsMajorVersion,
              ContentDocument.LatestPublishedVersion.FileType
            FROM ContentDocumentLinks
          )
        FROM Comments__c
        WHERE Order__c = :OrderId 
        ORDER BY CreatedDate ASC
      ];
        Map<String, String> mapUserName = new Map<String, String>();
        
        List<User> listUser = [SELECT Id, Name FROM User];
        for (User usert : listUser) {
            
            mapUserName.put(usert.Id, usert.Name);
        }
        
        Order OrderRelacionada = [
        SELECT Id, CaseNumber__c, AccountId, CreatedById
        FROM Order
        WHERE Id = :OrderId
        LIMIT 1
      ];
        
        User user = new User();
        if (UserId != null) {

            user = [SELECT Id, Name FROM User WHERE Id = :UserId];
        }
        
        List<Comentarios> ComentariosParaDisplay = new List<Comentarios>();
        if (!Comentarios.isEmpty()) {

            for (Comments__c comentario : Comentarios) {
                
                Integer i = 1;
                Comentarios eachComentario = new Comentarios();
                
                eachComentario.Files = new List<FileItem>();
                if (comentario.ContentDocumentLinks != null) {
                    
                    for (ContentDocumentLink link : comentario.ContentDocumentLinks) {
                        FileItem fi = new FileItem();
                        fi.Title = link.ContentDocument.LatestPublishedVersion.Title;
                        fi.Type  = link.ContentDocument.LatestPublishedVersion.FileType;
                        fi.URL   = link.ContentDocumentId;
                        eachComentario.Files.add(fi);
                    }
                }
                eachComentario.Document = !eachComentario.Files.isEmpty();
                // keep legacy single-file fields pointing to first file for backward compat
                if (eachComentario.Document) {
                    eachComentario.Title = eachComentario.Files[0].Title;
                    eachComentario.Type  = eachComentario.Files[0].Type;
                    eachComentario.URL   = eachComentario.Files[0].URL;
                }
                
                
                /*eachComentario.MensagemDoCliente = comentario.DescricaoDoComments__c !=
                    null
                    ? comentario.DescricaoDoComments__c
                    : null;*/
                eachComentario.MensagemDoAgente = comentario.Comment__c !=
                    null
                    ? comentario.Comment__c
                    : null;
                
                eachComentario.DataDaMensagem = (comentario.CreatedDate)
                    .format('h:mm a');
                
                if (
                    comentario.Agent__c == true
                ) {
                    eachComentario.MensagemDoAgente = comentario.Comment__c;
                    eachComentario.Agente = true;
                } else {
                    eachComentario.MensagemDoCliente = comentario.Comment__c;
                    eachComentario.Agente = false;
                }
                
                
                
                eachComentario.Id = i;
                String UserName = mapUserName.get(Comentario.CreatedById);
                
                if (OrderRelacionada.CreatedById == comentario.CreatedById) {
                    eachComentario.AccountQueCriouAOrder = true;
                }
                else {
                    eachComentario.AccountQueCriouAOrder = false;
                }
                eachComentario.NomeDoUtilizador = UserName;
                eachComentario.ComentarioId = comentario.Id;
                if (/*comentario.DescricaoDoComments__c != null ||*/ comentario.Comment__c != null ||  eachComentario.Title !=null ) {
                    ComentariosParaDisplay.add(eachComentario);
                    
                }
                
                if (
                    comentario.Comment__c == null /*&&
                    comentario.DescricaoDoComments__c == null*/
                ) {
                    eachComentario.MensagemBool = false;
                }
                else {
                    eachComentario.MensagemBool = true;
                }
                
                eachComentario.Favorito = comentario.Favorite__c == true ? true : false;
                if (eachComentario.MensagemDoAgente == null) {
                    eachComentario.isNull = true;
                }
                else {
                    eachComentario.isNull = false;
                }
                i++;
            }
            return ComentariosParaDisplay;
        }
        return null;
    }
    
    /**
     * @description Posts a new comment on an Order, sends it via MKIS integration, and attaches any files
     * @param OrderId The Id of the Order to post the comment on
     * @param Message The comment text message
     * @param files List of File wrapper objects to attach to the comment
     * @return True if the comment was successfully saved, false otherwise
     */
    @AuraEnabled
    public static Boolean PostComentario(String OrderId, String Message, List<File> files ) {
        
        Boolean saved = false;
        String orderNumber = String.ValueOf([SELECT ID, OrderNumber FROM Order WHERE Id =: OrderId LIMIT 1].OrderNumber);

        if(!sendComentario(OrderId, Message, files)){
            return saved;
        }

        Comments__c Comentario = new Comments__c();
        
        Comentario.Comment__c = Message;
        Comentario.Order__c = OrderId;
        Comentario.Agent__c = true;

        insert Comentario;
        
        if (!files.isEmpty()) {
            
            List<ContentVersion> listFileToInsert = new List<ContentVersion>();
            List<ContentDocumentLink> listContentDocumentLink = new List<ContentDocumentLink>();
            for (File file : files) {
                
                ContentVersion ContVerFile = new ContentVersion();
                ContVerFile.VersionData = EncodingUtil.base64Decode(file.fileBody);
                ContVerFile.Title = file.fileName;
                ContVerFile.ContentLocation = 's';
                ContVerFile.PathOnClient = file.fileName;
                
                listFileToInsert.add(ContVerFile);
            }
        
            insert listFileToInsert;
            
            List<Id> listId = new List<Id>();
            
            for (ContentVersion ContentVersion : listFileToInsert) {
                listId.add(ContentVersion.Id);
            }
            
            List<ContentVersion> listIds = [SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :listId ];
            for (ContentVersion Idd : listIds) {
                
                ContentDocumentLink cDe = new ContentDocumentLink();
                cDe.ContentDocumentId = Idd.ContentDocumentId;
                cDe.LinkedEntityId = Comentario.Id;
                cDe.ShareType = 'I';
                cDe.Visibility = 'AllUsers';
                listContentDocumentLink.add(cDe);
            }
            
            insert listContentDocumentLink;
        }

        saved = true;

        return saved;
    }
    
    /**
     * @description Toggles the favorite status of a comment
     * @param ComentarioId The Id of the Comments__c record to toggle
     * @return The new favorite status of the comment
     */
    @AuraEnabled
    public static Boolean FavoritoComentario(string ComentarioId) {
        Comments__c c = [
        SELECT Id, Favorite__c
        FROM Comments__c
        WHERE Id = :ComentarioId
      ];
        if (c.Favorite__c == true) {
            c.Favorite__c = false;
        } else {
            c.Favorite__c = true;
        }
        update c;
        return c.Favorite__c;
    }

    /**
     * @description Builds the request payload and sends a comment to the external service via HTTP
     * @param servicoID The Id of the Order (service) to send the comment for
     * @param message The comment text message
     * @param files List of File wrapper objects to include as attachments
     * @return True if the HTTP call was successful, false otherwise
     */
    private static Boolean sendComentario(String servicoID, String message, List<File> files){
        
        Call call = new Call();
        call.order_id = [SELECT OrderNumber FROM Order WHERE Id =: servicoID LIMIT 1].Id;
        call.body = message;
        if (files != null && !files.isEmpty()) {
            call.attachments = new List<Files>();
            for (File file : files) {
                Files filesService = new Files();
                filesService.name = file.fileName;
                filesService.content = file.fileBody;
                call.attachments.add(filesService);
            }
        }

        String body = JSON.serialize(call, true);
        System.debug(body);
        
        return httpCall(body);
    }

    /**
     * @description Executes an HTTP POST callout to the MKIS ELBA /messages endpoint
     * @param body The JSON request body to send
     * @return True if the response status code is 200, false otherwise
     */
    private static Boolean httpCall(String body){
        
        HttpResponse res = new HttpResponse();
        if (!Test.isRunningTest()) {
            res = MKISElbaCalloutService.doPost('/messages', body);
        } else {
            res.setStatusCode(200);
        }
        System.debug(body);
        System.debug(res.getBody());

        return res.getStatusCode() == 200;
    }
    
    public class Comentarios {
        @AuraEnabled
        public String MensagemDoCliente { get; set; }
        @AuraEnabled
        public String MensagemDoAgente { get; set; }
        @AuraEnabled
        public String DataDaMensagem { get; set; }
        @AuraEnabled
        public Boolean Agente { get; set; }
        @AuraEnabled
        public Integer Id { get; set; }
        @AuraEnabled
        public String NomeDoUtilizador { get; set; }
        @AuraEnabled
        public Boolean AccountQueCriouAOrder { get; set; }
        @AuraEnabled
        public String ComentarioId { get; set; }
        @AuraEnabled
        public String Title { get; set; }
        @AuraEnabled
        public String Type { get; set; }
        @AuraEnabled
        public Boolean Document { get; set; }
        @AuraEnabled
        public Boolean MensagemBool { get; set; }
        @AuraEnabled
        public String URL { get; set; }
        @AuraEnabled
        public Boolean Favorito { get; set; }
        @AuraEnabled
        public Boolean isNull { get; set; }
        @AuraEnabled
        public List<FileItem> Files { get; set; }
    }

    public class FileItem {
        @AuraEnabled
        public String Title { get; set; }
        @AuraEnabled
        public String Type { get; set; }
        @AuraEnabled
        public String URL { get; set; }
    }
    
    public class File {
        @AuraEnabled
        public String fileName { get; set; }
        @AuraEnabled
        public String fileType { get; set; }
        @AuraEnabled
        public String fileBody { get; set; }
    }

    public class Call {
        @AuraEnabled
        public String order_id { get; set; }
        @AuraEnabled
        public String body { get; set; }
         @AuraEnabled
        public List<files> attachments { get; set; }

    }
    public class files{
        @AuraEnabled 
        public String name { get; set; }
        @AuraEnabled 
        public String content { get; set; }
       
    }


}