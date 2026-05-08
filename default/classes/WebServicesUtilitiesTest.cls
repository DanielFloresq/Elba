/**
 * @description       : Classe de testes para a classe WebServicesUtilities que testa tanto a resposta de sucesso como a de erro
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 06-17-2025
 * @last modified by  : Luís Angeja
**/
@isTest
private class WebServicesUtilitiesTest { 

    private class MockHttp implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"data": "fake-token"}');
            res.setStatusCode(200);
            return res;
        }
    }

    private class MockHttpError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"error": "Unauthorized"}');
            return res;
        }
    }

    /**
     * @description Verifies that the login method returns a valid token on a successful HTTP 200 response.
     */
    @isTest
    static void testLoginSuccess() {
        Test.startTest();

        Test.setMock(HttpCalloutMock.class, new MockHttp());
        String token = WebServicesUtilities.login();
        System.debug(token);

        Test.stopTest();

        System.assertEquals('fake-token', token, 'Token deve ser igual ao da resposta.');
    }

    /**
     * @description Verifies that the login method throws a CalloutException when the HTTP response indicates an error.
     */
    @isTest
    static void testLoginErrorResponse() {
        Test.startTest();

        Test.setMock(HttpCalloutMock.class, new MockHttpError());

        try {
            WebServicesUtilities.login();
            System.assert(false, 'Deveria lançar exceção em resposta com erro');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Error STATUS: 401'), 'Mensagem de erro deve conter o código de status');
        }

        Test.stopTest();
    }
}