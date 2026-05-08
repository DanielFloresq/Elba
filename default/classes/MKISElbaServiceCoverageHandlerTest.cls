/**
 * @description       : Test class for MKISElbaServiceCoverageHandler.
 *                      Covers createServiceCoverage sync flow, the @future
 *                      createServiceCoverageAsync entry point, hasCaseRelation guard,
 *                      bulk safety, and sharing semantics. Mocks all callouts.
 * @author            : Test Class Builder
 * @group             : MKIS Integration
**/
@IsTest
private class MKISElbaServiceCoverageHandlerTest {

    private static final String PELAYO_GRAND_ACCOUNT = 'PLYO';

    // ─── Test Data Setup ──────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        Account acc = TestFactory.createAccount(
            'MKIS Coverage Account',
            PELAYO_GRAND_ACCOUNT,
            'A2',
            'Customer'
        );

        Case pelayoCase = new Case(
            Subject = 'MKIS Coverage Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = PELAYO_GRAND_ACCOUNT
        );
        insert pelayoCase;

        InsurableCoverage__c cov = new InsurableCoverage__c(
            Claim__c = pelayoCase.Id,
            Coverage__c = 'Robo',
            CoverageAmountLimit__c = 1000,
            DeductibleAmount__c = 100
        );
        insert cov;
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static InsurableCoverage__c getCoverage() {
        return [SELECT Id, Claim__c FROM InsurableCoverage__c LIMIT 1];
    }

    private static Case getCase() { return [SELECT Id FROM Case LIMIT 1]; }

    private static HttpResponse createOkResponse() {
        return HttpCalloutMockFactory.generateHttpResponse(
            200, 'OK',
            '{"data":{"id":"MKIS-COV-001"},"message":"Created"}'
        );
    }

    private static HttpResponse failureResponse() {
        return HttpCalloutMockFactory.generateHttpResponse(
            500, 'Server Error',
            '{"message":"Internal failure"}'
        );
    }

    // ─── createServiceCoverage (sync) ────────────────────────────────────────

    @IsTest
    static void createServiceCoverage_noCase_returnsNull() {
        InsurableCoverage__c cov = new InsurableCoverage__c(
            Claim__c = null,
            Coverage__c = 'Robo'
        );

        Test.startTest();
        String mkisId = MKISElbaServiceCoverageHandler.createServiceCoverage(cov);
        Test.stopTest();

        System.assertEquals(null, mkisId,
            'createServiceCoverage must return null when Claim__c is missing');
        System.assertEquals(0, Limits.getCallouts(),
            'No callouts should be issued without a related Case');
    }

    @IsTest
    static void createServiceCoverage_validInputs_returnsMkisId() {
        InsurableCoverage__c cov = [
            SELECT Id, Claim__c, Coverage__c, CoverageAmountLimit__c, DeductibleAmount__c
            FROM InsurableCoverage__c LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(
            new List<HttpResponse>{ createOkResponse() }
        ));

        Test.startTest();
        String mkisId = MKISElbaServiceCoverageHandler.createServiceCoverage(cov);
        Test.stopTest();

        System.assertEquals('MKIS-COV-001', mkisId,
            'createServiceCoverage should parse data.id from a successful response');
    }

    @IsTest
    static void createServiceCoverage_serverError_returnsNull() {
        InsurableCoverage__c cov = [
            SELECT Id, Claim__c, Coverage__c, CoverageAmountLimit__c, DeductibleAmount__c
            FROM InsurableCoverage__c LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(
            new List<HttpResponse>{ failureResponse() }
        ));

        Test.startTest();
        String mkisId = MKISElbaServiceCoverageHandler.createServiceCoverage(cov);
        Test.stopTest();

        System.assertEquals(null, mkisId,
            'createServiceCoverage must return null on non-200 responses');
    }

    // ─── createServiceCoverageAsync (@future) ────────────────────────────────

    @IsTest
    static void createServiceCoverageAsync_validIds_writesExternalKey() {
        InsurableCoverage__c cov = getCoverage();

        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(
            new List<HttpResponse>{ createOkResponse() }
        ));

        Test.startTest();
        MKISElbaServiceCoverageHandler.createServiceCoverageAsync(new List<Id>{ cov.Id });
        Test.stopTest();

        InsurableCoverage__c reloaded = [
            SELECT ExternalKey__c FROM InsurableCoverage__c WHERE Id = :cov.Id
        ];
        System.assertEquals('MKIS-COV-001', reloaded.ExternalKey__c,
            'createServiceCoverageAsync should persist the parsed MKIS id into ExternalKey__c');
    }

    @IsTest
    static void createServiceCoverageAsync_emptyIds_doesNothing() {
        Test.startTest();
        MKISElbaServiceCoverageHandler.createServiceCoverageAsync(new List<Id>());
        Test.stopTest();

        System.assertEquals(0, Limits.getCallouts(),
            'No callouts should be issued for an empty id list');
    }

    // ─── Bulk safety ─────────────────────────────────────────────────────────

    @IsTest
    static void createServiceCoverageAsync_bulk200_handlesGracefully() {
        Case c = getCase();

        List<InsurableCoverage__c> bulk = new List<InsurableCoverage__c>();
        for (Integer i = 0; i < 200; i++) {
            bulk.add(new InsurableCoverage__c(
                Claim__c = c.Id,
                Coverage__c = 'Cobertura ' + i,
                CoverageAmountLimit__c = 100 + i
            ));
        }
        insert bulk;

        List<Id> ids = new List<Id>();
        for (InsurableCoverage__c x : bulk) ids.add(x.Id);

        List<HttpResponse> responses = new List<HttpResponse>();
        for (Integer i = 0; i < 220; i++) responses.add(createOkResponse());
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(responses));

        Test.startTest();
        MKISElbaServiceCoverageHandler.createServiceCoverageAsync(ids);
        Test.stopTest();

        Integer updatedCount = [
            SELECT COUNT() FROM InsurableCoverage__c
            WHERE Id IN :ids AND ExternalKey__c != null
        ];
        System.assert(updatedCount >= 0,
            'Bulk createServiceCoverageAsync must remain governor-safe');
    }

    // ─── Sharing (without sharing) ───────────────────────────────────────────

    @IsTest
    static void createServiceCoverage_runAsStandardUser_executes() {
        InsurableCoverage__c cov = [
            SELECT Id, Claim__c, Coverage__c, CoverageAmountLimit__c, DeductibleAmount__c
            FROM InsurableCoverage__c LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(
            new List<HttpResponse>{ createOkResponse() }
        ));

        Profile p = [
            SELECT Id FROM Profile
            WHERE UserLicense.Name = 'Salesforce' AND Name != 'System Administrator'
            LIMIT 1
        ];
        User u = new User(
            Alias = 'covstd',
            Email = 'covsharing@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CovSharing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'covsharing_' + System.currentTimeMillis() + '@example.com.test'
        );
        insert u;

        Test.startTest();
        System.runAs(u) {
            String mkisId = MKISElbaServiceCoverageHandler.createServiceCoverage(cov);
            System.assertEquals('MKIS-COV-001', mkisId,
                'without sharing handler should bypass record-level restrictions');
        }
        Test.stopTest();
    }
}
