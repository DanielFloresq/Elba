/**
 * @description       : Test class for gerarCartaPdfController PDF generation operations
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 04-02-2026
 * @last modified by  : Afonso Duque
**/
@IsTest
public class gerarCartaPdfControllerTest {
    /**
     * @description Tests template retrieval, merge, save, and PDF creation flow
     */
    @IsTest
    static void getTemplateTest(){
        Case caso = [SELECT Id,ContactId,CaseNumber FROM Case LIMIT 1];
        Test.startTest();
        List<EmailTemplate> emailTemplst = gerarCartaPdfController.getTemplates('abc');
        String responseMergeHtml = '<p>Test</p>';
        String templateName = 'Template';
        if (!emailTemplst.isEmpty()) {
            responseMergeHtml = gerarCartaPdfController.mergeTemplate(emailTemplst[0].Id, caso.ContactId, caso.Id);
            templateName = emailTemplst[0].Name;
        }
        gerarCartaPdfController.SaveHtmlResult result = gerarCartaPdfController.saveHtmlTemplate(caso.Id, responseMergeHtml);
        gerarCartaPdfController.PdfResult respostaCreate = gerarCartaPdfController.createPdf(caso.Id, caso.CaseNumber, templateName);

        PageReference pdfPage = Page.cartaPdfPage;
        Test.setCurrentPage(pdfPage);
        pdfPage.getParameters().put('recordId',caso.Id);
        gerarCartaPdfController ctrl = new gerarCartaPdfController();
        Test.stopTest();
    }

    /**
     * @description Creates test data including Contact and Case records for PDF generation tests
     */
    @TestSetup
    static void makeData(){
        Contact cont = new Contact();
        cont.LastName = 'Teste';
        /* cont.Ramo__c = '30';
        cont.Subramo__c = 'MRH VINCULADOS';
        cont.LastName = 'Test';
        cont.Rua__c = 'Test';
        cont.Pais__c = 'POR';
        cont.Codigo_Postal__c = '1600-459'; */
        cont.Phone = '+351962149290';
        insert cont;

        Case c = new Case();
        c.ContactId = cont.Id;
        c.Subject = 'Teste';
        c.Status = 'New';
        c.Origin = 'Phone';
        /* c.Provisao_c_IVA_perito__c = 100;
        c.Segurado__c = cont.Id;
        c.Type = 'Sinistro';
        c.Cliente_tem_Informacao_Necessaria__c = true;
        c.Validacao_Historico_das_Coberturas__c = true;
        c.ValidacaoSeguradoraReabertura__c = 'Em Aprovação';
        c.Tipo_de_Interveniente__c = 'CLI';
        c.Data_do_Sinistro__c = Date.today();
        c.Causa_Sinistro__c = 'DANOS POR ÁGUA';
        c.Tipologia_de_Origem__c = 'INFILTRAÇÃO';
        c.Geolocalizacao__Latitude__s = 40.2213087;
        c.Geolocalizacao__Longitude__s = -8.5833358; */
        insert c;
    }
}