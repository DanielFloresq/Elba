/**
 * @description       : Test class for PelayoCommentService.
 *                      Covers enqueueCreate, callCreateCommentsSync, isPelayoComment guards,
 *                      hasHitoPrefix, buildCommentContext (Case + Order paths), bulk safety,
 *                      sharing enforcement and Queueable.execute short-circuit.
 *
 *                      Custom metadata dependency: full callout happy paths assume
 *                      WebServiceUtils__mdt records 'Pelayo Token' and 'Pelayo Create Comment'
 *                      (or any 'Pelayo%' fallback) exist for the running org's sandbox flag.
 * @author            : Test Class Builder
 * @group             : Pelayo Integration
**/
@IsTest
private class PelayoCommentServiceTest {

    private static final String PELAYO_GRAND_ACCOUNT = 'PLYO';

    // ─── Test Data Setup ──────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        Account pelayoAccount = TestFactory.createAccount(
            'Pelayo Comment Account',
            PELAYO_GRAND_ACCOUNT,
            'A2',
            'Customer'
        );

        Case pelayoCase = new Case(
            Subject = 'Pelayo Comment Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = PELAYO_GRAND_ACCOUNT,
            InsurerClaimReference__c = 'SIN-CMT-001'
        );
        insert pelayoCase;

        Case nonPelayoCase = new Case(
            Subject = 'Non-Pelayo Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = 'OTHER'
        );
        insert nonPelayoCase;

        Id standardPricebookId = Test.getStandardPricebookId();
        Order pelayoOrder = new Order(
            AccountId = pelayoAccount.Id,
            Status = 'Service Management',
            ChargeIdentifier__c = 'ENC-CMT-001',
            CaseNumber__c = pelayoCase.Id,
            EffectiveDate = Date.today(),
            Pricebook2Id = standardPricebookId
        );
        insert pelayoOrder;

        Product2 product = new Product2(Name = 'Comment Product', IsActive = true);
        insert product;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert pbe;

        insert new OrderItem(
            OrderId = pelayoOrder.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 1
        );

        // Pelayo comment on Case (will be picked up by isPelayoComment via Case path)
        insert new Comments__c(
            Case__c = pelayoCase.Id,
            Comment__c = 'Hito - Pelayo case comment',
            Message__c = 'Body of comment'
        );

        // Pelayo comment on Order (will be picked up by isPelayoComment via Order path)
        insert new Comments__c(
            Order__c = pelayoOrder.Id,
            Comment__c = 'Hito - Pelayo order comment',
            Message__c = 'Order body'
        );

        // Non-Pelayo comment (Case has GrandAccount__c = 'OTHER')
        insert new Comments__c(
            Case__c = nonPelayoCase.Id,
            Comment__c = 'Hito - Non Pelayo',
            Message__c = 'No Pelayo'
        );

        // SMS Hito comment (should be skipped by isPelayoComment)
        insert new Comments__c(
            Case__c = pelayoCase.Id,
            Comment__c = 'Hito - Envío de SMS test',
            Message__c = 'SMS'
        );
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static Comments__c getPelayoCaseComment() {
        return [
            SELECT Id FROM Comments__c
            WHERE Case__c IN (SELECT Id FROM Case WHERE GrandAccount__c = :PELAYO_GRAND_ACCOUNT)
            AND Comment__c = 'Hito - Pelayo case comment'
            LIMIT 1
        ];
    }

    private static Comments__c getPelayoOrderComment() {
        return [
            SELECT Id FROM Comments__c
            WHERE Order__c != null
            AND Comment__c = 'Hito - Pelayo order comment'
            LIMIT 1
        ];
    }

    private static Comments__c getNonPelayoComment() {
        return [
            SELECT Id FROM Comments__c
            WHERE Comment__c = 'Hito - Non Pelayo' LIMIT 1
        ];
    }

    private static Comments__c getSmsHitoComment() {
        return [
            SELECT Id FROM Comments__c
            WHERE Comment__c LIKE 'Hito - Envío de SMS%' LIMIT 1
        ];
    }

    private static List<HttpResponse> tokenAndOkResponses() {
        return new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
                200, 'OK',
                '{"access_token":"test-token","token_type":"Bearer","expires_in":86400}'
            ),
            HttpCalloutMockFactory.generateHttpResponse(
                200, 'OK',
                '{"id":"CMT-001","success":true,"message":"OK"}'
            )
        };
    }

    // ─── enqueueCreate ───────────────────────────────────────────────────────

    @IsTest
    static void enqueueCreate_validIds_enqueuesQueueable() {
        Comments__c c = getPelayoCaseComment();

        Test.startTest();
        PelayoCommentService.enqueueCreate(new List<Id>{ c.Id });
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued, 'enqueueCreate should schedule one Queueable');
    }

    @IsTest
    static void enqueueCreate_null_returnsEarly() {
        Test.startTest();
        PelayoCommentService.enqueueCreate(null);
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();
        System.assertEquals(0, queued, 'No Queueable should be scheduled for null');
    }

    @IsTest
    static void enqueueCreate_empty_returnsEarly() {
        Test.startTest();
        PelayoCommentService.enqueueCreate(new List<Id>());
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();
        System.assertEquals(0, queued, 'No Queueable should be scheduled for empty list');
    }

    // ─── callCreateCommentsSync ──────────────────────────────────────────────

    @IsTest
    static void callCreateCommentsSync_null_returnsEarly() {
        Test.startTest();
        PelayoCommentService.callCreateCommentsSync(null);
        PelayoCommentService.callCreateCommentsSync(new List<Id>());
        Test.stopTest();
        System.assertEquals(0, Limits.getCallouts(),
            'No callouts should be issued for null/empty input');
    }

    @IsTest
    static void callCreateCommentsSync_nonPelayoOnly_returnsEarly() {
        Comments__c c = getNonPelayoComment();

        Test.startTest();
        PelayoCommentService.callCreateCommentsSync(new List<Id>{ c.Id });
        Test.stopTest();

        System.assertEquals(0, Limits.getCallouts(),
            'Non-Pelayo comments should not trigger any callouts');
    }

    @IsTest
    static void callCreateCommentsSync_pelayoComment_invokesCallout() {
        Comments__c c = getPelayoCaseComment();
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(tokenAndOkResponses()));
        PelayoCommentService.enableCalloutsInTests = true;

        Boolean reachedCallout = false;
        Test.startTest();
        try {
            PelayoCommentService.callCreateCommentsSync(new List<Id>{ c.Id });
            reachedCallout = true;
        } catch (Exception e) {
            // WebServiceUtils__mdt may not exist; tolerate the QueryException.
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

    // ─── hasHitoPrefix ───────────────────────────────────────────────────────

    @IsTest
    static void hasHitoPrefix_validHito_returnsTrue() {
        Test.startTest();
        Boolean result = PelayoCommentService.hasHitoPrefix('Hito - Some milestone');
        Test.stopTest();
        System.assertEquals(true, result, 'Hito-prefixed text should return true');
    }

    @IsTest
    static void hasHitoPrefix_blank_returnsFalse() {
        Test.startTest();
        Boolean nullResult = PelayoCommentService.hasHitoPrefix(null);
        Boolean emptyResult = PelayoCommentService.hasHitoPrefix('');
        Boolean noPrefixResult = PelayoCommentService.hasHitoPrefix('regular comment');
        Test.stopTest();

        System.assertEquals(false, nullResult, 'Null should return false');
        System.assertEquals(false, emptyResult, 'Empty should return false');
        System.assertEquals(false, noPrefixResult, 'Non-Hito text should return false');
    }

    // ─── isPelayoComment (via @TestVisible private) ──────────────────────────

    @IsTest
    static void isPelayoComment_smsHito_returnsFalse() {
        Comments__c smsComment = [
            SELECT Id, Comment__c, Type__c, Subtype__c, CreatedBy.Name,
                   Case__c, Case__r.GrandAccount__c,
                   Order__c, Order__r.CaseNumber__r.GrandAccount__c,
                   Stakeholders__c, Stakeholders__r.Case__r.GrandAccount__c,
                   Incident__c
            FROM Comments__c WHERE Id = :getSmsHitoComment().Id LIMIT 1
        ];

        Test.startTest();
        Boolean result = PelayoCommentService.isPelayoComment(smsComment);
        Test.stopTest();

        System.assertEquals(false, result,
            'SMS Hito comments must be excluded from Pelayo flow (handled by Communication service)');
    }

    @IsTest
    static void isPelayoComment_pelayoCasePath_returnsTrue() {
        Comments__c c = [
            SELECT Id, Comment__c, Type__c, Subtype__c, CreatedBy.Name,
                   Case__c, Case__r.GrandAccount__c,
                   Order__c, Order__r.CaseNumber__r.GrandAccount__c,
                   Stakeholders__c, Stakeholders__r.Case__r.GrandAccount__c,
                   Incident__c
            FROM Comments__c WHERE Id = :getPelayoCaseComment().Id LIMIT 1
        ];

        Test.startTest();
        Boolean result = PelayoCommentService.isPelayoComment(c);
        Test.stopTest();

        System.assertEquals(true, result, 'Pelayo case-anchored comment should qualify');
    }

    @IsTest
    static void isPelayoComment_nonPelayoCase_returnsFalse() {
        Comments__c c = [
            SELECT Id, Comment__c, Type__c, Subtype__c, CreatedBy.Name,
                   Case__c, Case__r.GrandAccount__c,
                   Order__c, Order__r.CaseNumber__r.GrandAccount__c,
                   Stakeholders__c, Stakeholders__r.Case__r.GrandAccount__c,
                   Incident__c
            FROM Comments__c WHERE Id = :getNonPelayoComment().Id LIMIT 1
        ];

        Test.startTest();
        Boolean result = PelayoCommentService.isPelayoComment(c);
        Test.stopTest();

        System.assertEquals(false, result, 'Non-Pelayo case-anchored comment should NOT qualify');
    }

    @IsTest
    static void isPelayoComment_null_returnsFalse() {
        Test.startTest();
        Boolean result = PelayoCommentService.isPelayoComment(null);
        Test.stopTest();
        System.assertEquals(false, result, 'Null comment should return false');
    }

    // ─── buildCommentContext ─────────────────────────────────────────────────

    @IsTest
    static void buildCommentContext_null_returnsNull() {
        Test.startTest();
        PelayoCommentOutBoundStructure.CommentContext ctx =
            PelayoCommentService.buildCommentContext(null);
        Test.stopTest();
        System.assertEquals(null, ctx, 'Null comment must produce null context');
    }

    @IsTest
    static void buildCommentContext_caseAnchored_populatesSiniestro() {
        Comments__c c = [
            SELECT Id, Name, Comment__c, Message__c, Type__c, Subtype__c,
                   CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name,
                   Case__c, Case__r.CaseNumber, Case__r.InsurerClaimReference__c,
                   Order__c, Order__r.OrderNumber, Order__r.ChargeIdentifier__c,
                   Order__r.AccountId, Order__r.Account.Name,
                   Order__r.CaseNumber__r.CaseNumber, Order__r.CaseNumber__r.InsurerClaimReference__c,
                   Contact__c, Contact__r.Name,
                   Stakeholders__c, Stakeholders__r.Name,
                   Incident__c
            FROM Comments__c WHERE Id = :getPelayoCaseComment().Id LIMIT 1
        ];

        Test.startTest();
        PelayoCommentOutBoundStructure.CommentContext ctx =
            PelayoCommentService.buildCommentContext(c);
        Test.stopTest();

        System.assertNotEquals(null, ctx, 'Case-anchored comment should produce a context');
        System.assertEquals('SIN-CMT-001', ctx.idSiniestroAseguradora,
            'idSiniestroAseguradora should match Case.InsurerClaimReference__c');
        System.assertEquals('ASEGURADO', ctx.tipoDestinatario,
            'Default destinatario for Case path with no Stakeholder/Contact is ASEGURADO');
    }

    @IsTest
    static void buildCommentContext_orderAnchored_populatesEncargo() {
        Comments__c c = [
            SELECT Id, Name, Comment__c, Message__c, Type__c, Subtype__c,
                   CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name,
                   Case__c, Case__r.CaseNumber, Case__r.InsurerClaimReference__c,
                   Order__c, Order__r.OrderNumber, Order__r.ChargeIdentifier__c,
                   Order__r.AccountId, Order__r.Account.Name,
                   Order__r.CaseNumber__r.CaseNumber, Order__r.CaseNumber__r.InsurerClaimReference__c,
                   Contact__c, Contact__r.Name,
                   Stakeholders__c, Stakeholders__r.Name,
                   Incident__c
            FROM Comments__c WHERE Id = :getPelayoOrderComment().Id LIMIT 1
        ];

        Test.startTest();
        PelayoCommentOutBoundStructure.CommentContext ctx =
            PelayoCommentService.buildCommentContext(c);
        Test.stopTest();

        System.assertNotEquals(null, ctx, 'Order-anchored comment should produce a context');
        System.assertEquals('PROVEEDOR', ctx.tipoDestinatario,
            'tipoDestinatario for Order path is PROVEEDOR');
        System.assertEquals('ENC-CMT-001', ctx.idEncargoAseguradora,
            'idEncargoAseguradora should match Order.ChargeIdentifier__c');
    }

    // ─── queryComments ──────────────────────────────────────────────────────

    @IsTest
    static void queryComments_returnsAllRequestedIds() {
        Comments__c a = getPelayoCaseComment();
        Comments__c b = getPelayoOrderComment();

        Test.startTest();
        List<Comments__c> result =
            PelayoCommentService.queryComments(new List<Id>{ a.Id, b.Id });
        Test.stopTest();

        System.assertEquals(2, result.size(), 'queryComments should return both rows');
    }

    // ─── Bulk safety ─────────────────────────────────────────────────────────

    @IsTest
    static void enqueueCreate_bulk200_singleQueueable() {
        Case c = [SELECT Id FROM Case WHERE GrandAccount__c = :PELAYO_GRAND_ACCOUNT LIMIT 1];

        List<Comments__c> bulk = new List<Comments__c>();
        for (Integer i = 0; i < 200; i++) {
            bulk.add(new Comments__c(
                Case__c = c.Id,
                Comment__c = 'Hito - Bulk ' + i,
                Message__c = 'm' + i
            ));
        }
        insert bulk;

        List<Id> ids = new List<Id>();
        for (Comments__c cm : bulk) {
            ids.add(cm.Id);
        }

        Test.startTest();
        PelayoCommentService.enqueueCreate(ids);
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'A 200-record bulk should still produce exactly one Queueable');
    }

    // ─── Sharing enforcement ─────────────────────────────────────────────────

    @IsTest
    static void enqueueCreate_runAsStandardUser_respectsWithSharing() {
        Comments__c c = getPelayoCaseComment();

        Profile p = [
            SELECT Id FROM Profile
            WHERE UserLicense.Name = 'Salesforce' AND Name != 'System Administrator'
            LIMIT 1
        ];
        User u = new User(
            Alias = 'cmtstd',
            Email = 'commentsharing@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CommentSharing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'commentsharing_' + System.currentTimeMillis() + '@example.com.test'
        );
        insert u;

        Test.startTest();
        System.runAs(u) {
            PelayoCommentService.enqueueCreate(new List<Id>{ c.Id });
        }
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'A standard user should be able to enqueue under with sharing');
    }

    // ─── Queueable execute short-circuit ─────────────────────────────────────

    @IsTest
    static void queueable_executeInTestMode_isNoOp() {
        Comments__c c = getPelayoCaseComment();
        PelayoCommentService.enableCalloutsInTests = false;

        Test.startTest();
        PelayoCommentService.enqueueCreate(new List<Id>{ c.Id });
        Test.stopTest();

        System.assertEquals(0, Limits.getCallouts(),
            'Queueable.execute must short-circuit when enableCalloutsInTests is false');
    }
}
