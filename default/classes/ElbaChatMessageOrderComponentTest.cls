/**
 * @description       : Test class for ElbaChatMessageOrderController chat message operations
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 07-22-2025
 * @last modified by  : Daniel Flores
**/
@isTest
private class ElbaChatMessageOrderComponentTest {

    class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{}');
            res.setStatusCode(200);
            return res;
        }
    }

    /**
     * @description Sets up test data including Account, Order, and Comments__c records
     */
    @testSetup
    static void setup() {
        Account acc = new Account(Name = 'Conta Teste');
        insert acc;

        Order ord = new Order(
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = Date.today()
        );
        insert ord;
        Comments__c comment = new Comments__c(
            Order__c = ord.Id,
            Comment__c = 'Mensagem de teste',
            Favorite__c = false,
            Agent__c = true
        );
        insert comment;
    }

    /**
     * @description Tests retrieval of comments for an Order via GetComentarios
     */
    @isTest
    static void testGetComentarios() {
        User u = [SELECT Id FROM User LIMIT 1];
        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        List<ElbaChatMessageOrderController.Comentarios> result = ElbaChatMessageOrderController.GetComentarios(ord.Id, u.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size());
        System.assertEquals('Mensagem de teste', result[0].MensagemDoAgente);
    }

    /**
     * @description Tests posting a new comment with file attachment via PostComentario
     */
    @isTest
    static void testPostComentario() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Order ord = [SELECT Id FROM Order LIMIT 1];

        ElbaChatMessageOrderController.File testFile = new ElbaChatMessageOrderController.File();
        testFile.fileName = 'doc.txt';
        testFile.fileBody = EncodingUtil.base64Encode(Blob.valueOf('conteúdo'));
        testFile.fileType = 'txt';

        List<ElbaChatMessageOrderController.File> files = new List<ElbaChatMessageOrderController.File>{ testFile };

        Test.startTest();
        Boolean success = ElbaChatMessageOrderController.PostComentario(ord.Id, 'Nova mensagem de teste', files);
        Test.stopTest();

        System.assertEquals(true, success);
    }

    /**
     * @description Tests toggling the favorite status of a comment via FavoritoComentario
     */
    @isTest
    static void testFavoritoComentario() {
        Comments__c comment = [SELECT Id, Favorite__c FROM Comments__c LIMIT 1];
        Boolean favoritoAntes = comment.Favorite__c;

        Test.startTest();
        Boolean novoValor = ElbaChatMessageOrderController.FavoritoComentario(comment.Id);
        Test.stopTest();
        System.assertNotEquals(favoritoAntes, novoValor);
    }
}