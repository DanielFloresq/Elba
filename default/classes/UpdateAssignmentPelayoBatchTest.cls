/**
 * @description       : Test class for UpdateAssignmentPelayoBatch batch operations
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 26-02-2026
 * @last modified by  : Afonso Duque
**/
@isTest
public class UpdateAssignmentPelayoBatchTest {

    /**
     * @description Sets up test data including an Account, Case, and Order for batch test scenarios.
     */
    @TestSetup
    static void makeData(){
        Account testAccount = TestFactory.createAccount('Test Account', 'test@test.com' , '910000000', 'Multigremio', 'A2');
        Case testCase = TestFactory.createCase(testAccount.Id, 'En Curso', 'PLYO');
        Order testOrder = TestFactory.createOrder(testCase.Id, testAccount.Id, 'Order Assignment');
    }

    /**
     * @description Verifies that the UpdateAssignmentPelayoBatch correctly processes Order records and updates integration fields.
     */
    @isTest
    static void testBatchExecution() {

        // Mock the HTTP response for the token request to simulate success
        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
				'{"access_token":"123","token_type":"Bearer","expires_in":86400}'
			),
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"id":"71c45d26-fcae-4242-8d14-1c27bc51cb3f","success":true,"message":"Actualizacion procesada con exito.","idSiniestroElba":"123","idSiniestroAseguradora":"123","encargos":[{"idEncargoElba":"123", "idEncargoAseguradora":"123","success":true,"message":"Encargo actualizado correctamente"}]}'
            )
		};
        HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);
        Test.setMock(HttpCalloutMock.class, serviceMocks);

        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        List<String> orderIds = new List<String>{(String) testOrder.Id};

        Test.startTest();
        Database.executeBatch(new UpdateAssignmentPelayoBatch(orderIds, 'Assignacion'), 1);
        Test.stopTest();

        testOrder = [SELECT Id, ChargeIdentifier__c, LastIntegrationDateTime__c, LastIntegrationDescription__c FROM Order LIMIT 1];
        System.assertEquals('123', testOrder.ChargeIdentifier__c, 'The Charge Identifier should be updated based on the service response');
        System.assertNotEquals(null, testOrder.LastIntegrationDateTime__c, 'The Last Integration DateTime should be set');
        System.assertEquals('Encargo actualizado correctamente', testOrder.LastIntegrationDescription__c, 'The Last Integration Description should be updated based on the service response');
    }
}