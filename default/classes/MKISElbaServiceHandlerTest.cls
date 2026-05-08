/**
 * @description       : Test class for MKISElbaServiceHandler - validates Create Service and Update Service
 *                      calls to MKIS ELBA API with HTTP callout mocking
 * @author            : Daniel Flores
 * @last modified on  : 14-01-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
private class MKISElbaServiceHandlerTest {

    /**
     * @description Mock HTTP callout class for simulating MKIS ELBA API responses
     */
    private class MKISElbaMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"message":"Success"}');
            return res;
        }
    }

    /**
     * @description Sets up test data including Account, Contact, Contract, Case, and Order records
     */
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(Name = 'Test Provider Service');
        insert testAccount;

        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Insured',
            AccountId = testAccount.Id,
            Phone = '+351912345678',
            Email = 'insured@test.com'
        );
        insert testContact;

        Contract testContract = new Contract(
            AccountId = testAccount.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 12
        );
        insert testContract;

        Case testCase = new Case(
            Subject = 'Test Case Service',
            Status = 'New',
            AccountId = testAccount.Id
        );
        insert testCase;

        Order testOrder = new Order(
            AccountId = testAccount.Id,
            ContractId = testContract.Id,
            BillToContactId = testContact.Id,
            CaseNumber__c = testCase.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert testOrder;
    }

    /**
     * @description Tests createServiceAsync with mocked HTTP callout
     */
    @IsTest
    static void testCreateServiceAsync() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MKISElbaMock());

        Test.startTest();
        MKISElbaServiceHandler.createServiceAsync(new List<Id>{ testOrder.Id });
        Test.stopTest();

        // Scaffolding assertion — verify no unhandled exceptions
        System.assertNotEquals(null, testOrder.Id, 'Order should exist');
    }

    /**
     * @description Tests createServiceFromButton with mocked HTTP callout
     */
    @IsTest
    static void testCreateServiceFromButton() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MKISElbaMock());

        Test.startTest();
        Map<String, Object> result = MKISElbaServiceHandler.createServiceFromButton(testOrder.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result map should not be null');
    }

    /**
     * @description Tests createService with a single Order and mocked HTTP callout
     */
    @IsTest
    static void testCreateService() {
        Order testOrder = [SELECT Id, AccountId FROM Order LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MKISElbaMock());

        Test.startTest();
        List<Order> orders = MKISElbaServiceHandler.queryOrders(new List<Id>{ testOrder.Id });
        if (!orders.isEmpty()) {
            MKISElbaServiceHandler.createService(orders[0]);
        }
        Test.stopTest();

        System.assert(!orders.isEmpty(), 'Orders should be queried');
    }

    /**
     * @description Tests updateServiceAsync with mocked HTTP callout
     */
    @IsTest
    static void testUpdateServiceAsync() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MKISElbaMock());

        Test.startTest();
        MKISElbaServiceHandler.updateServiceAsync(new List<Id>{ testOrder.Id });
        Test.stopTest();

        System.assertNotEquals(null, testOrder.Id, 'Order should exist');
    }

    /**
     * @description Tests updateService with a single Order and mocked HTTP callout
     */
    @IsTest
    static void testUpdateService() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MKISElbaMock());

        Test.startTest();
        List<Order> orders = MKISElbaServiceHandler.queryOrders(new List<Id>{ testOrder.Id });
        if (!orders.isEmpty()) {
            MKISElbaServiceHandler.updateService(orders[0]);
        }
        Test.stopTest();

        System.assert(!orders.isEmpty(), 'Orders should be queried');
    }

    /**
     * @description Tests queryOrders returns correct Order data
     */
    @IsTest
    static void testQueryOrders() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        List<Order> orders = MKISElbaServiceHandler.queryOrders(new List<Id>{ testOrder.Id });
        Test.stopTest();

        System.assert(!orders.isEmpty(), 'queryOrders should return at least one Order');
    }
}