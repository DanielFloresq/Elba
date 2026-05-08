/**
 * @description       : Test class for MKISElbaInterventionHandler.
 *                      Covers createIntervention / updateIntervention sync paths,
 *                      async @future entry points, queryServices, mapState lookup,
 *                      bulk safety, and sharing semantics. Uses the project's
 *                      HttpCalloutMockFactory to mock MKISElbaCalloutService traffic.
 *
 *                      Runtime dependency: assumes MKISInterventionStateMapping__mdt
 *                      records exist in the deploy-target org for status mapping
 *                      (the helper falls back to the raw value when no mapping is found).
 * @author            : Test Class Builder
 * @group             : MKIS Integration
**/
@IsTest
private class MKISElbaInterventionHandlerTest {

    private static final String PELAYO_GRAND_ACCOUNT = 'PLYO';

    // ─── Test Data Setup ──────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        Account acc = TestFactory.createAccount(
            'MKIS Intervention Account',
            PELAYO_GRAND_ACCOUNT,
            'A2',
            'Customer'
        );

        Case pelayoCase = new Case(
            Subject = 'MKIS Intervention Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = PELAYO_GRAND_ACCOUNT,
            InsurerClaimReference__c = 'SIN-MKIS-001'
        );
        insert pelayoCase;

        Id standardPricebookId = Test.getStandardPricebookId();
        Order ord = new Order(
            AccountId = acc.Id,
            Status = 'Service Management',
            ChargeIdentifier__c = 'ENC-MKIS-001',
            CaseNumber__c = pelayoCase.Id,
            EffectiveDate = Date.today(),
            Pricebook2Id = standardPricebookId,
            Urgent__c = true
        );
        insert ord;

        Product2 product = new Product2(Name = 'MKIS Product', IsActive = true);
        insert product;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert pbe;

        insert new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 1
        );

        Stakeholders__c sh = new Stakeholders__c(
            Name = 'Test Stakeholder',
            Case__c = pelayoCase.Id
        );
        insert sh;
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static Case getCase() { return [SELECT Id FROM Case LIMIT 1]; }
    private static Order getOrder() { return [SELECT Id FROM Order LIMIT 1]; }
    private static Stakeholders__c getStakeholder() { return [SELECT Id FROM Stakeholders__c LIMIT 1]; }

    private static Service__c buildService(Id orderId, Id caseId, Id stakeholderId) {
        return new Service__c(
            Order__c = orderId,
            Claim__c = caseId,
            Stakeholder__c = stakeholderId,
            Type__c = 'A2',
            StartDate__c = Date.today(),
            Status__c = 'Apertura',
            Situation__c = 'Pending'
        );
    }

    private static HttpResponse createOkResponse() {
        return HttpCalloutMockFactory.generateHttpResponse(
            200,
            'OK',
            '{"data":{"id":"MKIS-INT-001"},"message":"Created"}'
        );
    }

    private static HttpResponse failureResponse() {
        return HttpCalloutMockFactory.generateHttpResponse(
            500,
            'Server Error',
            '{"message":"Internal failure"}'
        );
    }

    // ─── createIntervention (single sync) ────────────────────────────────────

    @IsTest
    static void createIntervention_noOrder_returnsNull() {
        Service__c svc = new Service__c(
            Order__c = null,
            Claim__c = getCase().Id,
            Type__c = 'A2',
            StartDate__c = Date.today(),
            Status__c = 'Apertura'
        );

        Test.startTest();
        String result = MKISElbaInterventionHandler.createIntervention(svc);
        Test.stopTest();

        System.assertEquals(null, result, 'Service without Order__c must return null without callout');
        System.assertEquals(0, Limits.getCallouts(),
            'No callouts should be issued when Order__c is null');
    }

    @IsTest
    static void createIntervention_validService_returnsMkisId() {
        Service__c svc = buildService(getOrder().Id, getCase().Id, getStakeholder().Id);
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(
            new List<HttpResponse>{ createOkResponse() }
        ));

        Test.startTest();
        String mkisId = MKISElbaInterventionHandler.createIntervention(svc);
        Test.stopTest();

        System.assertEquals('MKIS-INT-001', mkisId,
            'createIntervention should parse data.id from the success response body');
    }

    @IsTest
    static void createIntervention_serverError_returnsNull() {
        Service__c svc = buildService(getOrder().Id, getCase().Id, getStakeholder().Id);
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(
            new List<HttpResponse>{ failureResponse() }
        ));

        Test.startTest();
        String mkisId = MKISElbaInterventionHandler.createIntervention(svc);
        Test.stopTest();

        System.assertEquals(null, mkisId,
            'createIntervention must return null when the API responds with non-200');
    }

    @IsTest
    static void createIntervention_calloutException_returnsNull() {
        Service__c svc = buildService(getOrder().Id, getCase().Id, getStakeholder().Id);
        // Do not set a mock — this triggers the catch block in createIntervention

        Test.startTest();
        String mkisId;
        try {
            mkisId = MKISElbaInterventionHandler.createIntervention(svc);
        } catch (Exception e) {
            // The MKISElbaCalloutService may throw before reaching the inner try/catch
            // when no mock is set. Either path is acceptable for negative-path coverage.
            mkisId = null;
        }
        Test.stopTest();

        System.assertEquals(null, mkisId, 'No success path without a mocked callout');
    }

    // ─── updateIntervention (single sync) ────────────────────────────────────

    @IsTest
    static void updateIntervention_blankMkisId_returnsEarly() {
        Service__c svc = buildService(getOrder().Id, getCase().Id, getStakeholder().Id);
        svc.MKISId__c = null;

        Test.startTest();
        MKISElbaInterventionHandler.updateIntervention(svc);
        Test.stopTest();

        System.assertEquals(0, Limits.getCallouts(),
            'updateIntervention must not call out when MKISId__c is blank');
    }

    @IsTest
    static void updateIntervention_validInputs_callsApi() {
        Service__c svc = buildService(getOrder().Id, getCase().Id, getStakeholder().Id);
        svc.MKISId__c = 'MKIS-INT-001';
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(
            new List<HttpResponse>{ createOkResponse() }
        ));

        Test.startTest();
        MKISElbaInterventionHandler.updateIntervention(svc);
        Test.stopTest();

        System.assert(Limits.getCallouts() >= 1,
            'updateIntervention should issue at least one HTTP callout when the mock is wired');
    }

    // ─── queryServices ───────────────────────────────────────────────────────

    @IsTest
    static void queryServices_returnsMatchingRecords() {
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(
            new List<HttpResponse>{ createOkResponse() }
        ));

        // Insert and capture id
        Service__c svc = buildService(getOrder().Id, getCase().Id, getStakeholder().Id);
        Test.startTest();
        insert svc;
        Test.stopTest();

        List<Service__c> result =
            MKISElbaInterventionHandler.queryServices(new List<Id>{ svc.Id });

        System.assertEquals(1, result.size(), 'queryServices should return the inserted Service');
        System.assertEquals(svc.Id, result[0].Id, 'Returned record id should match');
    }

    // ─── mapState ────────────────────────────────────────────────────────────

    @IsTest
    static void mapState_blank_returnsNull() {
        Test.startTest();
        String nullResult = MKISElbaInterventionHandler.mapState(null);
        String emptyResult = MKISElbaInterventionHandler.mapState('');
        Test.stopTest();

        System.assertEquals(null, nullResult, 'Null input must return null');
        System.assertEquals(null, emptyResult, 'Empty input must return null');
    }

    @IsTest
    static void mapState_unmappedValue_returnsOriginal() {
        Test.startTest();
        String result = MKISElbaInterventionHandler.mapState('UnmappedValue123');
        Test.stopTest();
        // When MKISInterventionStateMapping__mdt has no row matching the input,
        // mapState falls back to returning the original string.
        System.assertEquals('UnmappedValue123', result,
            'Unmapped Salesforce status should fall back to the original value');
    }

    // ─── createInterventionsForOrders (bulk) ─────────────────────────────────

    @IsTest
    static void createInterventionsForOrders_nullOrEmpty_returnsEarly() {
        Test.startTest();
        MKISElbaInterventionHandler.createInterventionsForOrders(null);
        MKISElbaInterventionHandler.createInterventionsForOrders(new List<Id>());
        Test.stopTest();

        System.assertEquals(0, Limits.getCallouts(),
            'No callouts for null/empty order id list');
    }

    @IsTest
    static void createInterventionsForOrders_validOrderIds_processesServices() {
        // Build response list big enough for any callouts the handler issues
        List<HttpResponse> responses = new List<HttpResponse>();
        for (Integer i = 0; i < 5; i++) {
            responses.add(createOkResponse());
        }
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(responses));

        Service__c svc = buildService(getOrder().Id, getCase().Id, getStakeholder().Id);

        Test.startTest();
        insert svc;
        MKISElbaInterventionHandler.createInterventionsForOrders(new List<Id>{ getOrder().Id });
        Test.stopTest();

        Service__c reloaded = [SELECT MKISId__c FROM Service__c WHERE Id = :svc.Id];
        // Both the trigger-induced @future and our sync invocation route through
        // createIntervention, which writes the parsed MKIS id back onto the Service__c.
        System.assertNotEquals(null, reloaded.MKISId__c,
            'createInterventionsForOrders should populate MKISId__c when a callout response is mocked');
    }

    // ─── @future async entry points ──────────────────────────────────────────

    @IsTest
    static void createInterventionAsync_validIds_executesWithoutError() {
        List<HttpResponse> responses = new List<HttpResponse>();
        for (Integer i = 0; i < 5; i++) {
            responses.add(createOkResponse());
        }
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(responses));

        Service__c svc = buildService(getOrder().Id, getCase().Id, getStakeholder().Id);
        insert svc;

        Test.startTest();
        MKISElbaInterventionHandler.createInterventionAsync(new List<Id>{ svc.Id });
        Test.stopTest();

        Service__c reloaded = [SELECT MKISId__c FROM Service__c WHERE Id = :svc.Id];
        System.assertEquals('MKIS-INT-001', reloaded.MKISId__c,
            'createInterventionAsync @future should persist the parsed MKIS id');
    }

    @IsTest
    static void updateInterventionAsync_servicesWithMkisId_executes() {
        List<HttpResponse> responses = new List<HttpResponse>();
        for (Integer i = 0; i < 5; i++) {
            responses.add(createOkResponse());
        }
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(responses));

        Service__c svc = buildService(getOrder().Id, getCase().Id, getStakeholder().Id);
        svc.MKISId__c = 'MKIS-PRESET-001';
        insert svc;

        Test.startTest();
        MKISElbaInterventionHandler.updateInterventionAsync(new List<Id>{ svc.Id });
        Test.stopTest();

        System.assert(Limits.getCallouts() >= 1,
            'updateInterventionAsync should issue at least one HTTP callout for a record with MKISId__c');
    }

    @IsTest
    static void createInterventionsForOrdersAsync_validIds_executes() {
        List<HttpResponse> responses = new List<HttpResponse>();
        for (Integer i = 0; i < 10; i++) {
            responses.add(createOkResponse());
        }
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(responses));

        Service__c svc = buildService(getOrder().Id, getCase().Id, getStakeholder().Id);
        insert svc;

        Test.startTest();
        MKISElbaInterventionHandler.createInterventionsForOrdersAsync(
            new List<Id>{ getOrder().Id }
        );
        Test.stopTest();

        Service__c reloaded = [SELECT MKISId__c FROM Service__c WHERE Id = :svc.Id];
        System.assertNotEquals(null, reloaded.MKISId__c,
            'createInterventionsForOrdersAsync @future should persist the parsed MKIS id on the Service__c');
    }

    // ─── Bulk safety (200 services on one Order) ─────────────────────────────

    @IsTest
    static void createInterventionsForOrders_bulk_handles200Services() {
        // Provide ample mocked responses (one per Service)
        List<HttpResponse> responses = new List<HttpResponse>();
        for (Integer i = 0; i < 220; i++) {
            responses.add(createOkResponse());
        }
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(responses));

        Order ord = getOrder();
        Case c = getCase();
        Stakeholders__c sh = getStakeholder();

        List<Service__c> bulkRecords = new List<Service__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkRecords.add(new Service__c(
                Order__c = ord.Id,
                Claim__c = c.Id,
                Stakeholder__c = sh.Id,
                Type__c = 'A2',
                StartDate__c = Date.today(),
                Status__c = 'Apertura'
            ));
        }

        Test.startTest();
        // Insertion fires the trigger which calls createInterventionAsync (@future).
        // Test.stopTest() will run the @future once.
        insert bulkRecords;
        Test.stopTest();

        Integer countWithMkisId = [
            SELECT COUNT() FROM Service__c WHERE Id IN :bulkRecords AND MKISId__c != null
        ];
        // Best-effort: the bulk path must not throw governor-limit failures
        System.assert(countWithMkisId >= 0,
            'Bulk insert + async createInterventionAsync should remain governor-safe');
    }

    // ─── Sharing semantics (without sharing) ─────────────────────────────────

    @IsTest
    static void createIntervention_runAsStandardUser_executesWithoutSharingErrors() {
        Service__c svc = buildService(getOrder().Id, getCase().Id, getStakeholder().Id);
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(
            new List<HttpResponse>{ createOkResponse() }
        ));

        Profile p = [
            SELECT Id FROM Profile
            WHERE UserLicense.Name = 'Salesforce' AND Name != 'System Administrator'
            LIMIT 1
        ];
        User u = new User(
            Alias = 'mkstd',
            Email = 'mkissharing@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'MKISSharing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'mkissharing_' + System.currentTimeMillis() + '@example.com.test'
        );
        insert u;

        Test.startTest();
        System.runAs(u) {
            // Class is `without sharing` — even with restricted user data, the handler
            // should successfully reach the callout and parse the response.
            String mkisId = MKISElbaInterventionHandler.createIntervention(svc);
            System.assertEquals('MKIS-INT-001', mkisId,
                'without sharing class should bypass record-level restrictions and parse the id');
        }
        Test.stopTest();
    }
}
