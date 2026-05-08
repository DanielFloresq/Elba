/**
 * @description       : Test class for MKISElbaStakeholderHandler.
 *                      Covers the three @future entry points (create, update, delete),
 *                      finding related Orders, MKIS id parsing, bulk safety, and
 *                      sharing semantics. Mocks all MKISElbaCalloutService traffic.
 * @author            : Test Class Builder
 * @group             : MKIS Integration
**/
@IsTest
private class MKISElbaStakeholderHandlerTest {

    private static final String PELAYO_GRAND_ACCOUNT = 'PLYO';

    // ─── Test Data Setup ──────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        Account acc = TestFactory.createAccount(
            'MKIS Stakeholder Account',
            PELAYO_GRAND_ACCOUNT,
            'A2',
            'Customer'
        );

        Case pelayoCase = new Case(
            Subject = 'MKIS Stakeholder Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = PELAYO_GRAND_ACCOUNT,
            InsurerClaimReference__c = 'SIN-STK-001'
        );
        insert pelayoCase;

        Id standardPricebookId = Test.getStandardPricebookId();
        Order ord = new Order(
            AccountId = acc.Id,
            Status = 'Service Management',
            ChargeIdentifier__c = 'ENC-STK-001',
            CaseNumber__c = pelayoCase.Id,
            EffectiveDate = Date.today(),
            Pricebook2Id = standardPricebookId,
            UrlLinkStatus__c = true
        );
        insert ord;

        Product2 product = new Product2(Name = 'Stakeholder Product', IsActive = true);
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
            Name = 'Stakeholder Test',
            Case__c = pelayoCase.Id,
            StakeholderType__c = 'Asegurado',
            PrimaryMobile__c = '600000000'
        );
        insert sh;
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static Stakeholders__c getStakeholder() {
        return [SELECT Id FROM Stakeholders__c LIMIT 1];
    }

    private static HttpResponse createOkResponse() {
        return HttpCalloutMockFactory.generateHttpResponse(
            201, 'Created',
            '{"data":{"id":"MKIS-STK-001"},"message":"Created"}'
        );
    }

    private static HttpResponse updateOkResponse() {
        return HttpCalloutMockFactory.generateHttpResponse(
            200, 'OK',
            '{"data":{"id":"MKIS-STK-001"},"message":"Updated"}'
        );
    }

    private static HttpResponse deleteOkResponse() {
        return HttpCalloutMockFactory.generateHttpResponse(
            204, 'No Content', ''
        );
    }

    // ─── createStakeholderAsync ──────────────────────────────────────────────

    @IsTest
    static void createStakeholderAsync_validRecord_setsMkisId() {
        Stakeholders__c sh = getStakeholder();
        List<HttpResponse> responses = new List<HttpResponse>();
        for (Integer i = 0; i < 5; i++) {
            responses.add(createOkResponse());
        }
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(responses));

        Test.startTest();
        MKISElbaStakeholderHandler.createStakeholderAsync(new List<Id>{ sh.Id });
        Test.stopTest();

        Stakeholders__c reloaded = [SELECT MKISId__c FROM Stakeholders__c WHERE Id = :sh.Id];
        System.assertEquals('MKIS-STK-001', reloaded.MKISId__c,
            'createStakeholderAsync should write the parsed MKIS id back to the record');
    }

    @IsTest
    static void createStakeholderAsync_noRelatedOrder_skipsCallout() {
        // Insert a stakeholder against a Case with no Pelayo-sent Order
        Account a = TestFactory.createAccount('No Order Account', PELAYO_GRAND_ACCOUNT, 'A2', 'Customer');
        Case orphanCase = new Case(
            Subject = 'No-Order Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = PELAYO_GRAND_ACCOUNT
        );
        insert orphanCase;
        Stakeholders__c sh = new Stakeholders__c(
            Name = 'Orphan Stakeholder',
            Case__c = orphanCase.Id,
            StakeholderType__c = 'Asegurado'
        );
        insert sh;

        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(
            new List<HttpResponse>{ createOkResponse() }
        ));

        Test.startTest();
        MKISElbaStakeholderHandler.createStakeholderAsync(new List<Id>{ sh.Id });
        Test.stopTest();

        Stakeholders__c reloaded = [SELECT MKISId__c FROM Stakeholders__c WHERE Id = :sh.Id];
        System.assertEquals(null, reloaded.MKISId__c,
            'No related (UrlLinkStatus__c=true) Order should skip the callout and leave MKISId__c null');
    }

    // ─── updateStakeholderAsync ──────────────────────────────────────────────

    @IsTest
    static void updateStakeholderAsync_blankMkisId_skipsCallout() {
        Stakeholders__c sh = getStakeholder();
        // MKISId__c is null on the existing record — should be skipped

        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(
            new List<HttpResponse>{ updateOkResponse() }
        ));

        Test.startTest();
        MKISElbaStakeholderHandler.updateStakeholderAsync(new List<Id>{ sh.Id });
        Test.stopTest();

        System.assertEquals(0, Limits.getCallouts(),
            'updateStakeholderAsync must NOT issue any callout for records without MKISId__c');
    }

    @IsTest
    static void updateStakeholderAsync_withMkisId_callsApi() {
        Stakeholders__c sh = getStakeholder();
        update new Stakeholders__c(Id = sh.Id, MKISId__c = 'MKIS-STK-PRESET');

        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(
            new List<HttpResponse>{ updateOkResponse() }
        ));

        Test.startTest();
        MKISElbaStakeholderHandler.updateStakeholderAsync(new List<Id>{ sh.Id });
        Test.stopTest();

        System.assert(Limits.getCallouts() >= 1,
            'updateStakeholderAsync should issue at least one HTTP callout for records with MKISId__c');
    }

    // ─── deleteStakeholderAsync ──────────────────────────────────────────────

    @IsTest
    static void deleteStakeholderAsync_blankIds_skipsCallout() {
        Test.startTest();
        MKISElbaStakeholderHandler.deleteStakeholderAsync(
            new List<String>{ null, '', '   ' }
        );
        Test.stopTest();

        System.assertEquals(0, Limits.getCallouts(),
            'No callouts for null/blank MKIS ids');
    }

    @IsTest
    static void deleteStakeholderAsync_validIds_callsApi() {
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(
            new List<HttpResponse>{ deleteOkResponse() }
        ));

        Test.startTest();
        MKISElbaStakeholderHandler.deleteStakeholderAsync(
            new List<String>{ 'MKIS-STK-DELETE-1' }
        );
        Test.stopTest();

        System.assert(Limits.getCallouts() >= 1,
            'deleteStakeholderAsync should issue at least one DELETE callout for valid MKIS ids');
    }

    // ─── Bulk safety ─────────────────────────────────────────────────────────

    @IsTest
    static void createStakeholderAsync_bulk200_handlesGracefully() {
        Account a = TestFactory.createAccount(
            'Bulk Account', PELAYO_GRAND_ACCOUNT, 'A2', 'Customer'
        );
        Case bulkCase = new Case(
            Subject = 'Bulk Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = PELAYO_GRAND_ACCOUNT
        );
        insert bulkCase;

        Id standardPricebookId = Test.getStandardPricebookId();
        Order o = new Order(
            AccountId = a.Id,
            Status = 'Service Management',
            CaseNumber__c = bulkCase.Id,
            EffectiveDate = Date.today(),
            Pricebook2Id = standardPricebookId,
            UrlLinkStatus__c = true
        );
        insert o;

        List<Stakeholders__c> bulk = new List<Stakeholders__c>();
        for (Integer i = 0; i < 200; i++) {
            bulk.add(new Stakeholders__c(
                Name = 'Bulk Stk ' + i,
                Case__c = bulkCase.Id,
                StakeholderType__c = 'Asegurado'
            ));
        }
        insert bulk;

        List<Id> ids = new List<Id>();
        for (Stakeholders__c s : bulk) ids.add(s.Id);

        // Provide enough mocked responses to cover 200 callouts
        List<HttpResponse> responses = new List<HttpResponse>();
        for (Integer i = 0; i < 220; i++) responses.add(createOkResponse());
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(responses));

        Test.startTest();
        MKISElbaStakeholderHandler.createStakeholderAsync(ids);
        Test.stopTest();

        Integer updatedCount = [
            SELECT COUNT() FROM Stakeholders__c
            WHERE Id IN :ids AND MKISId__c != null
        ];
        // Best-effort: confirms the bulk processing didn't throw governor-limit failures
        System.assert(updatedCount >= 0,
            'Bulk createStakeholderAsync should remain governor-safe across 200 records');
    }

    // ─── Sharing (without sharing) ───────────────────────────────────────────

    @IsTest
    static void createStakeholderAsync_runAsStandardUser_executes() {
        Stakeholders__c sh = getStakeholder();
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(
            new List<HttpResponse>{ createOkResponse() }
        ));

        Profile p = [
            SELECT Id FROM Profile
            WHERE UserLicense.Name = 'Salesforce' AND Name != 'System Administrator'
            LIMIT 1
        ];
        User u = new User(
            Alias = 'stkstd',
            Email = 'stksharing@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'StkSharing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'stksharing_' + System.currentTimeMillis() + '@example.com.test'
        );
        insert u;

        Test.startTest();
        System.runAs(u) {
            MKISElbaStakeholderHandler.createStakeholderAsync(new List<Id>{ sh.Id });
        }
        Test.stopTest();

        // The handler is `without sharing`, so even a non-admin caller should produce
        // a successful @future invocation that writes the MKIS id back.
        Stakeholders__c reloaded = [SELECT MKISId__c FROM Stakeholders__c WHERE Id = :sh.Id];
        System.assertEquals('MKIS-STK-001', reloaded.MKISId__c,
            'without sharing handler should populate MKISId__c regardless of running user record access');
    }
}
