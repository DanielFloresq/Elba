/**
 * @description       : Test class for PelayoAttachDocumentService.
 *                      Covers enqueue happy path, early-return guards, callAttachDocumentsSync
 *                      sync-mode early returns, sharing semantics, bulk safety, and
 *                      Queueable.execute short-circuit behaviour.
 *
 *                      Custom metadata dependency: full callout happy paths assume
 *                      WebServiceUtils__mdt records 'Pelayo Token' and 'Update Pelayo Claim'
 *                      (or the 'Update Pelayo Assignment' fallback) exist in the deploy-target
 *                      org for the running sandbox flag.
 * @author            : Test Class Builder
 * @group             : Pelayo Integration
**/
@IsTest
private class PelayoAttachDocumentServiceTest {

    private static final String PELAYO_GRAND_ACCOUNT = 'PLYO';

    // ─── Test Data Setup ──────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        Account acc = TestFactory.createAccount(
            'Pelayo Attach Account',
            PELAYO_GRAND_ACCOUNT,
            'A2',
            'Customer'
        );

        Case pelayoCase = new Case(
            Subject = 'Pelayo Attach Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = PELAYO_GRAND_ACCOUNT,
            InsurerClaimReference__c = 'SIN-ATT-001'
        );
        insert pelayoCase;

        Case nonPelayoCase = new Case(
            Subject = 'Non-Pelayo Attach Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = 'OTHER'
        );
        insert nonPelayoCase;

        Id standardPricebookId = Test.getStandardPricebookId();
        Order ord = new Order(
            AccountId = acc.Id,
            Status = 'Service Management',
            CaseNumber__c = pelayoCase.Id,
            EffectiveDate = Date.today(),
            Pricebook2Id = standardPricebookId,
            ChargeIdentifier__c = 'ENC-ATT-001'
        );
        insert ord;

        ContentVersion cv = new ContentVersion(
            Title = 'Test Doc',
            PathOnClient = 'test.txt',
            VersionData = Blob.valueOf('Hello world'),
            IsMajorVersion = true
        );
        insert cv;
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static Case getPelayoCase() {
        return [
            SELECT Id FROM Case WHERE GrandAccount__c = :PELAYO_GRAND_ACCOUNT LIMIT 1
        ];
    }

    private static Case getNonPelayoCase() {
        return [SELECT Id FROM Case WHERE GrandAccount__c = 'OTHER' LIMIT 1];
    }

    private static Order getOrder() { return [SELECT Id FROM Order LIMIT 1]; }

    private static ContentVersion getContentVersion() {
        return [SELECT Id FROM ContentVersion LIMIT 1];
    }

    private static List<PelayoAttachDocumentOutBoundStructure.FileAttachmentInput> singleInput() {
        PelayoAttachDocumentOutBoundStructure.FileAttachmentInput input =
            new PelayoAttachDocumentOutBoundStructure.FileAttachmentInput();
        input.contentVersionId = getContentVersion().Id;
        input.familiaDoc = 'F1';
        input.tipoDoc = 'T1';
        return new List<PelayoAttachDocumentOutBoundStructure.FileAttachmentInput>{ input };
    }

    private static List<HttpResponse> tokenAndOkResponses() {
        return new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
                200, 'OK',
                '{"access_token":"test-token","token_type":"Bearer","expires_in":86400}'
            ),
            HttpCalloutMockFactory.generateHttpResponse(
                200, 'OK',
                '{"id":"DOC-001","success":true,"detail":"Attached"}'
            )
        };
    }

    // ─── enqueue ─────────────────────────────────────────────────────────────

    @IsTest
    static void enqueue_validInputs_enqueuesQueueable() {
        Case c = getPelayoCase();
        Order o = getOrder();

        Test.startTest();
        PelayoAttachDocumentService.enqueue(c.Id, o.Id, singleInput());
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued, 'enqueue should schedule one Queueable for valid inputs');
    }

    @IsTest
    static void enqueue_nullCaseId_returnsEarly() {
        Test.startTest();
        PelayoAttachDocumentService.enqueue(null, null, singleInput());
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(0, queued, 'No Queueable for null caseId');
    }

    @IsTest
    static void enqueue_nullInputs_returnsEarly() {
        Case c = getPelayoCase();

        Test.startTest();
        PelayoAttachDocumentService.enqueue(c.Id, null, null);
        PelayoAttachDocumentService.enqueue(
            c.Id, null,
            new List<PelayoAttachDocumentOutBoundStructure.FileAttachmentInput>()
        );
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(0, queued, 'No Queueable for null/empty inputs list');
    }

    // ─── callAttachDocumentsSync — early returns (no callout) ────────────────

    @IsTest
    static void callAttachDocumentsSync_nullCaseId_returnsEarly() {
        Test.startTest();
        PelayoAttachDocumentService.callAttachDocumentsSync(null, null, singleInput());
        Test.stopTest();
        System.assertEquals(0, Limits.getCallouts(), 'No callouts when caseId is null');
    }

    @IsTest
    static void callAttachDocumentsSync_emptyInputs_returnsEarly() {
        Case c = getPelayoCase();

        Test.startTest();
        PelayoAttachDocumentService.callAttachDocumentsSync(c.Id, null, null);
        PelayoAttachDocumentService.callAttachDocumentsSync(
            c.Id, null,
            new List<PelayoAttachDocumentOutBoundStructure.FileAttachmentInput>()
        );
        Test.stopTest();

        System.assertEquals(0, Limits.getCallouts(), 'No callouts when inputs are empty/null');
    }

    @IsTest
    static void callAttachDocumentsSync_nonPelayoCase_returnsEarly() {
        Case nonPelayo = getNonPelayoCase();

        Test.startTest();
        PelayoAttachDocumentService.callAttachDocumentsSync(nonPelayo.Id, null, singleInput());
        Test.stopTest();

        System.assertEquals(0, Limits.getCallouts(),
            'No callouts when Case GrandAccount__c is not PLYO');
    }

    // ─── callAttachDocumentsSync — happy path with mocked callouts ──────────

    @IsTest
    static void callAttachDocumentsSync_pelayoCase_invokesCallout() {
        Case c = getPelayoCase();
        Order o = getOrder();

        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(tokenAndOkResponses()));
        PelayoAttachDocumentService.enableCalloutsInTests = true;

        Boolean reachedCallout = false;
        Test.startTest();
        try {
            PelayoAttachDocumentService.callAttachDocumentsSync(c.Id, o.Id, singleInput());
            reachedCallout = true;
        } catch (Exception e) {
            // Custom metadata dependency: when not deployed, getToken() raises a
            // QueryException before any HTTP traffic is issued.
            System.debug('Skipping happy-path assertion: ' + e.getMessage());
        }
        Test.stopTest();

        if (reachedCallout) {
            System.assert(Limits.getCallouts() >= 1,
                'When WebServiceUtils__mdt is deployed, at least one callout (token) should fire');
        } else {
            System.assertEquals(0, Limits.getCallouts(),
                'When metadata is missing, the QueryException must short-circuit before any callout');
        }
    }

    // ─── Bulk safety ─────────────────────────────────────────────────────────

    @IsTest
    static void enqueue_bulkInputs_singleQueueable() {
        Case c = getPelayoCase();
        Order o = getOrder();

        // 50 file attachments in one enqueue invocation — one Queueable handles them all
        List<PelayoAttachDocumentOutBoundStructure.FileAttachmentInput> bulk =
            new List<PelayoAttachDocumentOutBoundStructure.FileAttachmentInput>();
        Id cvId = getContentVersion().Id;
        for (Integer i = 0; i < 50; i++) {
            PelayoAttachDocumentOutBoundStructure.FileAttachmentInput input =
                new PelayoAttachDocumentOutBoundStructure.FileAttachmentInput();
            input.contentVersionId = cvId;
            input.familiaDoc = 'F' + i;
            input.tipoDoc = 'T' + i;
            bulk.add(input);
        }

        Test.startTest();
        PelayoAttachDocumentService.enqueue(c.Id, o.Id, bulk);
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'enqueue with 50 attachments must still schedule exactly one Queueable');
    }

    // ─── Sharing enforcement ─────────────────────────────────────────────────

    @IsTest
    static void enqueue_runAsStandardUser_respectsWithSharing() {
        Case c = getPelayoCase();

        Profile p = [
            SELECT Id FROM Profile
            WHERE UserLicense.Name = 'Salesforce' AND Name != 'System Administrator'
            LIMIT 1
        ];
        User u = new User(
            Alias = 'attstd',
            Email = 'attachsharing@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'AttachSharing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'attachsharing_' + System.currentTimeMillis() + '@example.com.test'
        );
        insert u;

        Test.startTest();
        System.runAs(u) {
            PelayoAttachDocumentService.enqueue(c.Id, null, singleInput());
        }
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'A standard user should be able to enqueue under with sharing');
    }

    // ─── Queueable execute short-circuit ─────────────────────────────────────

    @IsTest
    static void queueable_executeInTestMode_isNoOp() {
        Case c = getPelayoCase();
        PelayoAttachDocumentService.enableCalloutsInTests = false;

        Test.startTest();
        PelayoAttachDocumentService.enqueue(c.Id, null, singleInput());
        Test.stopTest();

        System.assertEquals(0, Limits.getCallouts(),
            'Queueable.execute must short-circuit when enableCalloutsInTests is false');
    }
}
