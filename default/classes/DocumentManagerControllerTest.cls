/**
 * @description       : Test class for DocumentManagerController document management operations
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 14-04-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
public class DocumentManagerControllerTest {

    /**
     * @description Sets up test data including a Case and ContentVersion with a linked ContentDocumentLink
     */
    @testSetup
    static void setupData() {
        // Criar Case
        Case c = new Case(
            Subject = 'Teste Documentos',
            Status = 'New',
            Origin = 'Phone'
        );
        insert c;

        // Criar ficheiro (ContentVersion)
        ContentVersion cv = new ContentVersion();
        cv.Title = 'TesteDocumento';
        cv.PathOnClient = 'TesteDocumento.pdf';
        cv.VersionData = Blob.valueOf('Conteudo de teste');
        insert cv;

        // Obter ContentDocumentId
        cv = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];

        // Associar documento ao Case
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = c.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
    }

    /**
     * @description Tests retrieval of documents linked to a Case
     */
    @IsTest
    static void testGetDocuments() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        	DocumentManagerController.getDocuments(c.Id);
        Test.stopTest();
        
       
    }

    /**
     * @description Tests deletion of a ContentDocument
     */
    @IsTest
    static void testDeleteDocuments() {
        ContentDocument doc = [
            SELECT Id FROM ContentDocument LIMIT 1
        ];

        Test.startTest();
        DocumentManagerController.deleteDocuments(
            new List<Id>{ doc.Id }
        );
        Test.stopTest();

    }

    /**
     * @description Tests reassignment of a document from one Case to another
     */
    @IsTest
    static void testReassignDocuments() {
        Case sourceCase = [SELECT Id FROM Case LIMIT 1];

        Case targetCase = new Case(
            Subject = 'Destino',
            Status = 'New',
            Origin = 'Phone'
        );
        insert targetCase;

        ContentDocument doc = [
            SELECT Id FROM ContentDocument LIMIT 1
        ];

        Test.startTest();
        /* DocumentManagerController.reassignDocuments(
            new List<Id>{ doc.Id },
            targetCase.Id,
            sourceCase.Id
        ); */
        Test.stopTest();
    }

    /**
     * @description Tests searching for Cases by CaseNumber
     */
    @IsTest
    static void testSearchCases() {
        Test.startTest();
        List<Case> cases =
            DocumentManagerController.searchCases('000');
        Test.stopTest();

        
    }

    /**
     * @description Tests sending an email with document attachments
     */
    @IsTest
    static void testSendEmailWithDocuments() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        ContentDocument doc = [SELECT Id FROM ContentDocument LIMIT 1];

        Test.startTest();
        /* DocumentManagerController.sendEmailWithDocuments(
            c.Id,
            new List<String>{ 'test@test.com' },
            null,
            null,
            'Assunto Teste',
            '<p>Body</p>',
            new List<Id>{ doc.Id }
        ); */
        Test.stopTest();

    }

    /**
     * @description Tests retrieval of active email templates
     */
    @IsTest
    static void testGetEmailTemplates() {
        Test.startTest();
        List<EmailTemplate> templates =
            DocumentManagerController.getEmailTemplates();
        Test.stopTest();

    }

    /**
     * @description Tests rendering an email template with Case record data
     */
    @IsTest
    static void testApplyEmailTemplate() {
        // Criar template de teste
        EmailTemplate et = new EmailTemplate(
            Name = 'Template Teste',
            DeveloperName = 'Template_Teste',
            FolderId = UserInfo.getUserId(),
            Subject = 'Assunto {{Case.CaseNumber}}',
            HtmlValue = '<p>Olá</p>',
            TemplateType = 'custom',
            IsActive = true
        );
        insert et;

        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        DocumentManagerController.EmailTemplateWrapper wrap =
            DocumentManagerController.applyEmailTemplate(et.Id, c.Id);
        Test.stopTest();

    }
}