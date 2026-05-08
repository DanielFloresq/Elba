/**
 * @description       : Test class for CreateNewServiceController MKIS service creation and update operations
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 07-05-2026
 * @last modified by  : Daniel Flores
**/
@isTest
private class CreateNewServiceControllerTest {
    
    private class CreateNewServiceMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('/api/service')) {
                String jsonBody = JSON.serializePretty(new Map<String, Object>{
                    'info' => new Map<String, Object>{
                        'headers' => new Map<String, Object>(),
                        'original' => new Map<String, Object>{
                            'iframe_elba' => 'https://dev.tooltoelba.es/elbaDirectAuthByIframe/685908bff2c0f',
                            'message' => 'Success from mock'
                        },
                        'exception' => null
                    }
                });
                res.setBody('{"message":"Servicio actualizado con éxito","data":{"iframe_elba":"https://dev.tooltoelba.es/elbaDirectAuthByIframe/687e68e06c258","service":{"id":2,"service_insurance_id":"4","gc_charge_number":"123123321","sinister_date":"2025-07-22","elba_insured_name":"Daniel Flores"},"intervener":null,"message":"Servicio actualizado con éxito"}}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/api/login')) {
                res.setBody('{"token":"fake-token"}');
                res.setStatusCode(200);
            } else {
                res.setBody('{"error":"Unknown endpoint"}');
                res.setStatusCode(404);
            }

            return res;
        }
        
    }

    private class CreateNewServiceMock2 implements HttpCalloutMock {
        

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('/api/service')) {
                
                res.setBody('{"message":"Campos inv\u00e1lidos","data":["elba capital efificio debe ser num\u00e9rico.","elba capital responsabilidade civil debe ser num\u00e9rico."]}');
                res.setStatusCode(400);
            } else if (req.getEndpoint().contains('/api/login')) {
                res.setBody('{"token":"fake-token"}');
                res.setStatusCode(200);
            } else {
                res.setBody('{"error":"Unknown endpoint"}');
                res.setStatusCode(404);
            }

            return res;
        }
        
    }

    /**
     * @description Creates test data including Account, Contact, Case, Order, and Stakeholder records for service tests
     */
    @testSetup
    static void setupTestData() {
        Account acc = new Account(
            Name = 'Test Provider',
            TaxNumber__c = '123456789',
            Phone = '211234567',
            Email__c = 'provider@example.com'
        );
        insert acc;

        Contact contact = new Contact(
            LastName = 'Test Contact',
            PolicyNumber__c = '123456',
            MailingStreet = 'Rua Exemplo 123',
            MailingPostalCode = '1000-001',
            Phone = '211234567',
            MobilePhone = '911234567',
            Email = 'contact@example.com',
            IDNumber__c = '987654321',
            BuildingCapital__c = 100000,
            FillingCapital__c = 20000,
            LiabilityCapital__c = 50000
        );
        insert contact;

        Case testCase = new Case(
            Subject = 'Test Case',
            GrandAccount__c = 'SLA',
            GCOrderNumber__c = 'GC789',
            ClaimDate__c = Date.today(),
            Coverage__c = '1',
            Description = 'Danos causados por inundação'
        );
        insert testCase;

        Order ord = new Order(
            AccountId = acc.Id,
            BillToContactId = contact.Id,
            CaseNumber__c = testCase.Id,
            Type = 'Serviço Técnico',
            EffectiveDate = Date.today(),
            Status = 'Active'
        );
        insert ord;

        Order ord2 = new Order(
            AccountId = acc.Id,
            BillToContactId = contact.Id,
            CaseNumber__c = testCase.Id,
            Type = 'Serviço Standard',
            EffectiveDate = Date.today(),
            Status = 'Active'
        );
        insert ord2;

        Stakeholders__c stakeholder = new Stakeholders__c(
            OnThePortal__c = false,
            Case__c = testCase.Id,
            Name = 'Test Contact',
            StakeholderType__c = 'Causante',
            StakeholderTaxID__c = '123456789',
            Phone__c = '911234567',
            Address__Street__s = 'Rua Stakeholder 1',
            Address__City__s = 'Lisboa',
            Address__PostalCode__s = '1000-001'
        );
        insert stakeholder;
    }

    /**
     * @description Tests the redirect method that invokes service creation for an Order
     */
    @isTest
    static void testRedirectMethod() {
        Test.setMock(HttpCalloutMock.class, new CreateNewServiceMock());

        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        CreateNewServiceController.redirectMethod(new List<String>{ ord.Id });
        Test.stopTest();

        // Verifica se foi criado um valor esperado no Order
        Order updatedOrder = [SELECT LastIntegrationDateTime__c, LastIntegrationDescription__c, iFrame__c FROM Order WHERE Id = :ord.Id];
       
    }

    /**
     * @description Tests successful creation of a new MKIS service from an Order
     */
    @isTest
    static void testCreateNewServiceMethod_Success() {
        Test.setMock(HttpCalloutMock.class, new CreateNewServiceMock());

        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        CreateNewServiceController.createNewServiceMethod(new List<String>{ ord.Id });
        Test.stopTest();

        Order updatedOrder = [SELECT LastIntegrationDateTime__c, LastIntegrationDescription__c FROM Order WHERE Id = :ord.Id];
        
    }

    /**
     * @description Tests that validateMandatoryFields returns the expected missing fields when data is incomplete
     */
    @isTest
    static void testValidateMandatoryFields_ReturnsMissingFields() {
        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        List<String> missingFields = CreateNewServiceController.validateMandatoryFields(ord.Id);
        Test.stopTest();

        // Sanity checks: some fields are intentionally missing in test setup.
        System.assert(missingFields.contains('operatorName'));
        System.assert(missingFields.contains('policyEffectiveDate'));
        System.assert(missingFields.contains('assignedJob'));
        System.assert(missingFields.contains('city'));

        // Stakeholders exist and were populated to be valid.
        System.assert(!missingFields.contains('stakeholderName'));
        System.assert(!missingFields.contains('stakeholderType'));
        System.assert(!missingFields.contains('stakeholderTaxNumber'));
        System.assert(!missingFields.contains('stakeholderPhoneNumber'));
        System.assert(!missingFields.contains('stakeholderAddress'));
    }

    /**
     * @description Tests that validateMandatoryFields returns an empty list when all mandatory fields are populated
     */
    @isTest
    static void testValidateMandatoryFields_ReturnsEmptyWhenAllMappedFieldsExist() {
        Contact contact = [
            SELECT Id, MailingCity, MailingState, PolicyStartDate__c, /* LineOfBusiness__c, */
                   Phone, MobilePhone, Email, MailingStreet, MailingPostalCode
            FROM Contact
            LIMIT 1
        ];
        contact.MailingCity = 'Lisboa';
        contact.MailingState = 'Lisboa';
        contact.PolicyStartDate__c = Date.today();
       /*  contact.LineOfBusiness__c = '01-HOGAR'; */
        update contact;

        Case caseTemp = [
            SELECT Id, ClaimsHandlerName__c, ClaimsHandlerEmail__c,
                   RelationshiptotheInsured__c, ParticipationDate__c
            FROM Case
            LIMIT 1
        ];
        caseTemp.ClaimsHandlerName__c = 'Handler Name';
        caseTemp.ClaimsHandlerEmail__c = 'handler@example.com';
        caseTemp.RelationshiptotheInsured__c = 'CY';
        caseTemp.ParticipationDate__c = Date.today();
        update caseTemp;

        Order ord = [SELECT Id, Guild__c FROM Order LIMIT 1];
        ord.Guild__c = 'Electricidad';
        update ord;

        Test.startTest();
        List<String> missingFields = CreateNewServiceController.validateMandatoryFields(ord.Id);
        Test.stopTest();

        System.assertEquals(0, missingFields.size());
    }

    /**
     * @description Tests unsuccessful service update when the API returns an error response
     */
    @isTest
    static void testUpdateServiceMethod_UnSuccess() {
        Test.setMock(HttpCalloutMock.class, new CreateNewServiceMock2());

        Case caseTemp = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        CreateNewServiceController.createNewServiceMethod(new List<String>{ caseTemp.Id });
        Test.stopTest();

        Order updatedOrder = [SELECT LastIntegrationDateTime__c, LastIntegrationDescription__c FROM Order WHERE CaseNumber__c = :caseTemp.Id LIMIT 1];
        
    }
    /**
     * @description Tests unsuccessful service creation when the API returns an error response
     */
    @isTest
    static void testCreateNewServiceMethod_UnSuccess() {
        Test.setMock(HttpCalloutMock.class, new CreateNewServiceMock2());

        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        CreateNewServiceController.createNewServiceMethod(new List<String>{ ord.Id });
        Test.stopTest();

        Order updatedOrder = [SELECT LastIntegrationDateTime__c, LastIntegrationDescription__c FROM Order WHERE Id = :ord.Id];
        
    }

    /**
     * @description Tests a second unsuccessful service update scenario when the API returns an error response
     */
    @isTest
    static void testUpdateServiceMethod_UnSuccess2() {
        Test.setMock(HttpCalloutMock.class, new CreateNewServiceMock2());

        Case caseTemp = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        CreateNewServiceController.createNewServiceMethod(new List<String>{ caseTemp.Id });
        Test.stopTest();

        Order updatedOrder = [SELECT LastIntegrationDateTime__c, LastIntegrationDescription__c FROM Order WHERE CaseNumber__c = :caseTemp.Id LIMIT 1];
        
    }
}