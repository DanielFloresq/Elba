/**
 * @description       : Controller for generating PDF letters from templates with merge field support
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 04-02-2026
 * @last modified by  : Afonso Duque
**/
public with sharing class gerarCartaPdfController {
    public String body {get;set;}

    /**
     * @description Constructor that loads the letter template HTML body from the Case record
     */
    public gerarCartaPdfController() {
        String recordId = ApexPages.currentPage().getParameters().get('recordId');
        body = [SELECT TemplateCarta__c FROM Case WHERE Id = :recordId].TemplateCarta__c;
    }

    /**
     * @description Retrieves active email templates from the specified grand account folder, falling back to the Cartas folder
     * @param grandAccount The DeveloperName of the email template folder to search
     * @return List of matching active EmailTemplate records
     */
    @AuraEnabled(cacheable = true)
    public static List<EmailTemplate> getTemplates(String grandAccount){
        try {
            List<EmailTemplate> emailTemplates = [SELECT Id, Name FROM EmailTemplate WHERE isActive = true AND UiType = 'SFX' AND Folder.DeveloperName  =:grandAccount];
            if(emailTemplates.isEmpty()){
                emailTemplates = [SELECT Id, Name FROM EmailTemplate WHERE isActive = true AND UiType = 'SFX' AND Folder.DeveloperName  = 'Cartas'];
            }
            return emailTemplates;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Renders an email template with merge fields populated from the specified Contact and Case
     * @param templateId The Id of the EmailTemplate to render
     * @param contactId The Id of the Contact for merge field resolution
     * @param caseId The Id of the Case for merge field resolution
     * @return The rendered HTML body of the email template
     */
    @AuraEnabled
    public static String mergeTemplate(String templateId, String contactId, String caseId){
        try {
            Messaging.SingleEmailMessage message = Messaging.renderStoredEmailTemplate(templateId, contactId,caseId);
            return message.getHtmlBody();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Saves the HTML letter template content to the Case record
     * @param caseId The Id of the Case to update
     * @param html The HTML content to save as the letter template
     * @return SaveHtmlResult wrapper containing success status and case number
     */
    @AuraEnabled
    public static SaveHtmlResult saveHtmlTemplate(String caseId, String html){
        SaveHtmlResult result = new SaveHtmlResult();
        try {
            html = html.replaceAll('<img ', '<img class="insertedImg" ');
            Case caso = [SELECT Id, TemplateCarta__c, CaseNumber FROM Case WHERE Id = :caseId];
            caso.TemplateCarta__c = html;
            update caso;
            result.success = true;
            result.caseNumber = caso.CaseNumber;
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Generates a PDF from the Case letter template and creates a ContentDocument linked to the Case
     * @param caseId The Id of the Case to generate the PDF for
     * @param caseNumber The Case number used in the PDF title
     * @param templateName The template name used in the PDF title
     * @return PdfResult wrapper containing the ContentDocumentId and title
     */
    @AuraEnabled
    public static PdfResult createPdf(String caseId, String caseNumber, String templateName){
        try {
            PageReference pdfPage = Page.cartaPdfPage;
            pdfPage.getParameters().put('recordId',caseId);
            Blob pdfBlob;
            if(Test.isRunningTest()) { 
                pdfBlob = blob.valueOf('Unit.Test');
            } else {
                pdfBlob = pdfPage.getContent();
            }

            ContentVersion conVer = new ContentVersion();
            conVer.ContentLocation = 'S';
            conVer.VersionData = pdfBlob;
            conVer.Title = 'Processo '+ caseNumber + ' - ' + templateName;
            conVer.PathOnClient = conVer.Title + '.pdf';
            insert conVer;

            ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =: conVer.Id];
            ContentDocumentLink conDocLink = New ContentDocumentLink();
            conDocLink.LinkedEntityId = caseId;
            conDocLink.ContentDocumentId = cv.ContentDocumentId;
            conDocLink.Visibility = 'AllUsers';
            conDocLink.shareType = 'V';
            
            insert conDocLink;

            PdfResult result = new PdfResult();
            result.contentDocumentId = cv.ContentDocumentId;
            result.title = conVer.Title;
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class PdfResult {
        @AuraEnabled
        public String contentDocumentId;
        @AuraEnabled
        public String title;
    }

    public class SaveHtmlResult {
        @AuraEnabled
        public String caseNumber;
        @AuraEnabled
        public Boolean success;
    }
}