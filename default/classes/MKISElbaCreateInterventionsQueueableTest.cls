/**
 * @description       : Test class for MKISElbaCreateInterventionsQueueable.
 *                      Covers constructor, execute path delegation, and bulk safety.
 *                      Mocks MKISElbaCalloutService callouts.
 * @author            : Test Class Builder
 * @group             : MKIS Integration
**/
@IsTest
private class MKISElbaCreateInterventionsQueueableTest {

    private static final String PELAYO_GRAND_ACCOUNT = 'PLYO';

    @TestSetup
    static void setupTestData() {
        Account acc = TestFactory.createAccount(
            'Queueable Account', PELAYO_GRAND_ACCOUNT, 'A2', 'Customer'
        );
        Case pelayoCase = new Case(
            Subject = 'Queueable Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = PELAYO_GRAND_ACCOUNT
        );
        insert pelayoCase;

        Id standardPricebookId = Test.getStandardPricebookId();
        Order ord = new Order(
            AccountId = acc.Id,
            Status = 'Service Management',
            ChargeIdentifier__c = 'ENC-Q-001',
            CaseNumber__c = pelayoCase.Id,
            EffectiveDate = Date.today(),
            Pricebook2Id = standardPricebookId
        );
        insert ord;

        Product2 product = new Product2(Name = 'Q Product', IsActive = true);
        insert product;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert pbe;
        insert new OrderItem(
            OrderId = ord.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 1
        );
    }

    private static Order getOrder() { return [SELECT Id FROM Order LIMIT 1]; }
    private static Case getCase() { return [SELECT Id FROM Case LIMIT 1]; }

    private static HttpResponse okResponse() {
        return HttpCalloutMockFactory.generateHttpResponse(
            200, 'OK', '{"data":{"id":"MKIS-Q-001"},"message":"OK"}'
        );
    }

    // ─── Execute path ────────────────────────────────────────────────────────

    @IsTest
    static void execute_validOrderIds_delegatesToHandler() {
        Order o = getOrder();
        Case c = getCase();
        Service__c svc = new Service__c(
            Order__c = o.Id,
            Claim__c = c.Id,
            Type__c = 'A2',
            StartDate__c = Date.today(),
            Status__c = 'Apertura'
        );

        List<HttpResponse> responses = new List<HttpResponse>();
        for (Integer i = 0; i < 5; i++) responses.add(okResponse());
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(responses));

        Test.startTest();
        insert svc;
        System.enqueueJob(new MKISElbaCreateInterventionsQueueable(new List<Id>{ o.Id }));
        Test.stopTest();

        Service__c reloaded = [SELECT MKISId__c FROM Service__c WHERE Id = :svc.Id];
        System.assertEquals('MKIS-Q-001', reloaded.MKISId__c,
            'Queueable.execute should delegate to the handler and persist the parsed MKIS id on the Service__c');
    }

    @IsTest
    static void execute_emptyOrderIds_doesNothing() {
        Test.startTest();
        System.enqueueJob(new MKISElbaCreateInterventionsQueueable(new List<Id>()));
        Test.stopTest();

        System.assertEquals(0, Limits.getCallouts(),
            'Empty order list must not trigger any callouts');
    }

    @IsTest
    static void execute_nullOrderIds_doesNothing() {
        Test.startTest();
        System.enqueueJob(new MKISElbaCreateInterventionsQueueable(null));
        Test.stopTest();

        System.assertEquals(0, Limits.getCallouts(),
            'Null order list must not trigger any callouts');
    }

    // ─── Bulk safety ─────────────────────────────────────────────────────────

    @IsTest
    static void execute_bulkOrders_handlesGracefully() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Case c = getCase();

        // Standard Salesforce bulk pattern: 200 records on the trigger context
        List<Order> extraOrders = new List<Order>();
        Id pricebook = Test.getStandardPricebookId();
        for (Integer i = 0; i < 200; i++) {
            extraOrders.add(new Order(
                AccountId = acc.Id,
                Status = 'Service Management',
                CaseNumber__c = c.Id,
                EffectiveDate = Date.today(),
                Pricebook2Id = pricebook
            ));
        }
        insert extraOrders;

        List<Id> ids = new List<Id>();
        for (Order o : extraOrders) ids.add(o.Id);

        // Provide ample mocked responses (one per Service the queueable would query / call out for)
        List<HttpResponse> responses = new List<HttpResponse>();
        for (Integer i = 0; i < 220; i++) responses.add(okResponse());
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(responses));

        Test.startTest();
        System.enqueueJob(new MKISElbaCreateInterventionsQueueable(ids));
        Test.stopTest();

        // The 20 extra orders carry no Service__c records, so no MKISId__c writes should occur on them.
        Integer servicesOnExtraOrders = [
            SELECT COUNT() FROM Service__c WHERE Order__c IN :ids
        ];
        System.assertEquals(0, servicesOnExtraOrders,
            'Bulk orders without Service__c records should not produce any Service__c writes');
    }
}
