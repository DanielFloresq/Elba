/**
 * @description       : Test class for Order trigger handler and logic operations
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 06-03-2026
 * @last modified by  : Afonso Duque
**/
@isTest
public class OrderTriggerTest {

    /**
     * @description Tests Order trigger fires creation (AL) action for a new Pelayo Open order.
     **/
    @isTest
    static void testOrderTriggerCodeAL() {

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

        Test.startTest();

        Account testAccount = TestFactory.createAccount('Test Account', 'test@test.com' , '910000000', 'Multigremio', 'A2');
        Case testCase = TestFactory.createCase(testAccount.Id, 'En Curso', 'PLYO');
        Order testOrder = TestFactory.createOrder(testCase.Id, testAccount.Id, 'Open');

        Test.stopTest();

    }

    /**
     * @description Tests Order trigger fires assignation (AS) action when account changes to Supplier.
     **/
    @isTest
    static void testOrderTriggerCodeAS() {

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

        Test.startTest();

        OrderTriggerLogic.bypassExternalActions = true;
        Account testAccount = TestFactory.createAccount('Test Account', 'Multigremio', 'A2', 'InsuranceCompany');
        Account testSupplierAccount = TestFactory.createAccount('Test Supplier Account', 'Multigremio', 'A2', 'Supplier');
        Case testCase = TestFactory.createCase(testAccount.Id, 'En Curso', 'PLYO');
        Order testOrder = TestFactory.createOrder(testCase.Id, testAccount.Id, 'Open');
        OrderTriggerLogic.bypassExternalActions = false;

        testOrder.AccountId = testSupplierAccount.Id;
        testOrder.ChargeIdentifier__c = 'ExternalId123';
        update testOrder;

        Test.stopTest();

        testOrder = [SELECT Id, ChargeIdentifier__c, LastIntegrationDateTime__c, LastIntegrationDescription__c FROM Order LIMIT 1];
        System.assertEquals('123', testOrder.ChargeIdentifier__c, 'The Charge Identifier should be updated based on the service response');
        System.assertNotEquals(null, testOrder.LastIntegrationDateTime__c, 'The Last Integration DateTime should be set');
        System.assertEquals('Encargo actualizado correctamente', testOrder.LastIntegrationDescription__c, 'The Last Integration Description should be updated based on the service response');
    }

    /**
     * @description Tests Order trigger fires reassignment (RS) action when supplier account is changed.
     **/
    @isTest
    static void testOrderTriggerCodeRS() {

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

        Test.startTest();

        OrderTriggerLogic.bypassExternalActions = true;
        Account testAccount = TestFactory.createAccount('Test Account', 'Multigremio', 'A2', 'Supplier');
        Account testSupplierAccount = TestFactory.createAccount('Test Supplier Account', 'Multigremio', 'A2', 'Supplier');
        Case testCase = TestFactory.createCase(testAccount.Id, 'En Curso', 'PLYO');
        Order testOrder = TestFactory.createOrder(testCase.Id, testAccount.Id, 'Open');
        OrderTriggerLogic.bypassExternalActions = false;

        testOrder.AccountId = testSupplierAccount.Id;
        testOrder.ChargeIdentifier__c = 'ExternalId123';
        update testOrder;

        Test.stopTest();

        testOrder = [SELECT Id, ChargeIdentifier__c, LastIntegrationDateTime__c, LastIntegrationDescription__c FROM Order LIMIT 1];
        System.assertEquals('123', testOrder.ChargeIdentifier__c, 'The Charge Identifier should be updated based on the service response');
        System.assertNotEquals(null, testOrder.LastIntegrationDateTime__c, 'The Last Integration DateTime should be set');
        System.assertEquals('Encargo actualizado correctamente', testOrder.LastIntegrationDescription__c, 'The Last Integration Description should be updated based on the service response');
    }

    /**
     * @description Tests Order trigger fires closure (CE) action when status changes to Order Completed.
     **/
    @isTest
    static void testOrderTriggerCodeCE() {

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

        Test.startTest();

        OrderTriggerLogic.bypassExternalActions = true;
        Account testAccount = TestFactory.createAccount('Test Account', 'Multigremio', 'A2', 'Supplier');
        Case testCase = TestFactory.createCase(testAccount.Id, 'En Curso', 'PLYO');
        Order testOrder = TestFactory.createOrder(testCase.Id, testAccount.Id, 'Open');
        OrderTriggerLogic.bypassExternalActions = false;

        testOrder.Status = 'Order Completed';
        testOrder.ChargeIdentifier__c = 'ExternalId123';
        update testOrder;

        Test.stopTest();

        testOrder = [SELECT Id, ChargeIdentifier__c, LastIntegrationDateTime__c, LastIntegrationDescription__c FROM Order LIMIT 1];
        System.assertEquals('123', testOrder.ChargeIdentifier__c, 'The Charge Identifier should be updated based on the service response');
        System.assertNotEquals(null, testOrder.LastIntegrationDateTime__c, 'The Last Integration DateTime should be set');
        System.assertEquals('Encargo actualizado correctamente', testOrder.LastIntegrationDescription__c, 'The Last Integration Description should be updated based on the service response');
    }

    /**
     * @description Tests Order trigger fires cancellation (AN) action when status changes to Order Cancelled.
     **/
    @isTest
    static void testOrderTriggerCodeAN() {

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

        Test.startTest();

        OrderTriggerLogic.bypassExternalActions = true;
        Account testAccount = TestFactory.createAccount('Test Account', 'Multigremio', 'A2', 'Supplier');
        Case testCase = TestFactory.createCase(testAccount.Id, 'En Curso', 'PLYO');
        Order testOrder = TestFactory.createOrder(testCase.Id, testAccount.Id, 'Open');
        OrderTriggerLogic.bypassExternalActions = false;

        testOrder.Status = 'Order Cancelled';
        testOrder.ChargeIdentifier__c = 'ExternalId123';
        update testOrder;

        Test.stopTest();

        testOrder = [SELECT Id, ChargeIdentifier__c, LastIntegrationDateTime__c, LastIntegrationDescription__c FROM Order LIMIT 1];
        System.assertEquals('123', testOrder.ChargeIdentifier__c, 'The Charge Identifier should be updated based on the service response');
        System.assertNotEquals(null, testOrder.LastIntegrationDateTime__c, 'The Last Integration DateTime should be set');
        System.assertEquals('Encargo actualizado correctamente', testOrder.LastIntegrationDescription__c, 'The Last Integration Description should be updated based on the service response');
    }

    /**
     * @description Tests Order trigger fires avance (AV) action when avance-related fields change.
     **/
    @isTest
    static void testOrderTriggerCodeAV() {

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

        Test.startTest();

        OrderTriggerLogic.bypassExternalActions = true;
        Account testAccount = TestFactory.createAccount('Test Account', 'Multigremio', 'A2', 'Supplier');
        Case testCase = TestFactory.createCase(testAccount.Id, 'En Curso', 'PLYO');
        Order testOrder = TestFactory.createOrder(testCase.Id, testAccount.Id, 'Open');
        OrderTriggerLogic.bypassExternalActions = false;

        testOrder.Status = 'Order Assignment';
        testOrder.ChargeIdentifier__c = 'ExternalId123';
        update testOrder;

        Test.stopTest();

        testOrder = [SELECT Id, ChargeIdentifier__c, LastIntegrationDateTime__c, LastIntegrationDescription__c FROM Order LIMIT 1];
        System.assertEquals('123', testOrder.ChargeIdentifier__c, 'The Charge Identifier should be updated based on the service response');
        System.assertNotEquals(null, testOrder.LastIntegrationDateTime__c, 'The Last Integration DateTime should be set');
        System.assertEquals('Encargo actualizado correctamente', testOrder.LastIntegrationDescription__c, 'The Last Integration Description should be updated based on the service response');
    }

    /**
     * @description Tests Order trigger fires modification (MO) action for non-status field changes.
     **/
    @isTest
    static void testOrderTriggerCodeMO() {

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

        Test.startTest();

        OrderTriggerLogic.bypassExternalActions = true;
        Account testAccount = TestFactory.createAccount('Test Account', 'Multigremio', 'A2', 'Supplier');
        Case testCase = TestFactory.createCase(testAccount.Id, 'En Curso', 'PLYO');
        Order testOrder = TestFactory.createOrder(testCase.Id, testAccount.Id, 'Open');
        OrderTriggerLogic.bypassExternalActions = false;

        testOrder.Urgent__c = true;
        testOrder.ChargeIdentifier__c = 'ExternalId123';
        update testOrder;

        Test.stopTest();

        testOrder = [SELECT Id, ChargeIdentifier__c, LastIntegrationDateTime__c, LastIntegrationDescription__c FROM Order LIMIT 1];
        System.assertEquals('123', testOrder.ChargeIdentifier__c, 'The Charge Identifier should be updated based on the service response');
        System.assertNotEquals(null, testOrder.LastIntegrationDateTime__c, 'The Last Integration DateTime should be set');
        System.assertEquals('Encargo actualizado correctamente', testOrder.LastIntegrationDescription__c, 'The Last Integration Description should be updated based on the service response');
    }
}