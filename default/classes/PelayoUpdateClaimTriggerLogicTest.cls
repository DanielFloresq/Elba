/**
 * @description       : Test class for PelayoUpdateClaimTriggerLogic.
 *                      Covers processCases (insert + update with/without relevant changes,
 *                      non-Pelayo skip, bypass guard), processCaseIds (bypass + integration
 *                      user guards), isRelevantCaseChange field-by-field, and sharing semantics.
 *
 *                      bypassExternalActions defaults to false in production; tests
 *                      that need to skip the enqueue path explicitly flip it to true.
 * @author            : Test Class Builder
 * @group             : Pelayo Integration
**/
@IsTest
private class PelayoUpdateClaimTriggerLogicTest {

    private static final String PELAYO_GRAND_ACCOUNT = 'PLYO';

    // ─── Test Data Setup ──────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        Account acc = TestFactory.createAccount(
            'Trigger Logic Account',
            PELAYO_GRAND_ACCOUNT,
            'A2',
            'Customer'
        );

        Case pelayoCase = new Case(
            Subject = 'Pelayo Trigger Logic',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = PELAYO_GRAND_ACCOUNT,
            InsurerClaimReference__c = 'SIN-TRG-001'
        );
        insert pelayoCase;

        Case nonPelayoCase = new Case(
            Subject = 'Non-Pelayo',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = 'OTHER'
        );
        insert nonPelayoCase;
    }

    private static Case getPelayoCase() {
        return [SELECT Id, Subject, GrandAccount__c, InsurerClaimReference__c
                FROM Case WHERE GrandAccount__c = :PELAYO_GRAND_ACCOUNT LIMIT 1];
    }

    private static Case getNonPelayoCase() {
        return [SELECT Id, Subject, GrandAccount__c FROM Case WHERE GrandAccount__c = 'OTHER' LIMIT 1];
    }

    // ─── isRelevantCaseChange ────────────────────────────────────────────────

    @IsTest
    static void isRelevantCaseChange_subjectChanged_returnsTrue() {
        Case oldC = new Case(Subject = 'Old');
        Case newC = new Case(Subject = 'New');

        Test.startTest();
        Boolean result = PelayoUpdateClaimTriggerLogic.isRelevantCaseChange(oldC, newC);
        Test.stopTest();

        System.assertEquals(true, result, 'Subject change should be reported as relevant');
    }

    @IsTest
    static void isRelevantCaseChange_noChanges_returnsFalse() {
        Case oldC = new Case(
            Subject = 'Same',
            InsurerClaimReference__c = 'X',
            Urgent__c = false
        );
        Case newC = new Case(
            Subject = 'Same',
            InsurerClaimReference__c = 'X',
            Urgent__c = false
        );

        Test.startTest();
        Boolean result = PelayoUpdateClaimTriggerLogic.isRelevantCaseChange(oldC, newC);
        Test.stopTest();

        System.assertEquals(false, result, 'Identical cases must not be reported as changed');
    }

    @IsTest
    static void isRelevantCaseChange_urgentFlipped_returnsTrue() {
        Case oldC = new Case(Urgent__c = false);
        Case newC = new Case(Urgent__c = true);

        Test.startTest();
        Boolean result = PelayoUpdateClaimTriggerLogic.isRelevantCaseChange(oldC, newC);
        Test.stopTest();

        System.assertEquals(true, result, 'Urgent__c flip should count as relevant');
    }

    @IsTest
    static void isRelevantCaseChange_contactIdChanged_returnsTrue() {
        Account a = [SELECT Id FROM Account LIMIT 1];
        Contact c1 = new Contact(LastName = 'A', AccountId = a.Id);
        Contact c2 = new Contact(LastName = 'B', AccountId = a.Id);
        insert new List<Contact>{ c1, c2 };

        Case oldC = new Case(ContactId = c1.Id);
        Case newC = new Case(ContactId = c2.Id);

        Test.startTest();
        Boolean result = PelayoUpdateClaimTriggerLogic.isRelevantCaseChange(oldC, newC);
        Test.stopTest();

        System.assertEquals(true, result, 'ContactId change should be relevant');
    }

    // ─── processCases — bypass guard ─────────────────────────────────────────

    @IsTest
    static void processCases_bypassEnabled_skipsEnqueue() {
        Case c = getPelayoCase();
        Map<Id, Case> newMap = new Map<Id, Case>{ c.Id => c };

        // bypassExternalActions defaults to true in tests
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = true;

        Test.startTest();
        PelayoUpdateClaimTriggerLogic.processCases(newMap, null, true, false);
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(0, queued, 'Bypass true must skip enqueue');
    }

    @IsTest
    static void processCases_nullOrEmpty_returnsEarly() {
        Test.startTest();
        PelayoUpdateClaimTriggerLogic.processCases(null, null, true, false);
        PelayoUpdateClaimTriggerLogic.processCases(new Map<Id, Case>(), null, true, false);
        Test.stopTest();

        System.assertEquals(0, Limits.getQueueableJobs(),
            'Null/empty newMap should be a no-op');
    }

    @IsTest
    static void processCases_pelayoCaseInsert_enqueues() {
        Case c = getPelayoCase();
        Map<Id, Case> newMap = new Map<Id, Case>{ c.Id => c };

        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;

        Test.startTest();
        PelayoUpdateClaimTriggerLogic.processCases(newMap, null, true, false);
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'Insert of a Pelayo case should enqueue the updateClaim Queueable');
    }

    @IsTest
    static void processCases_nonPelayoInsert_doesNotEnqueue() {
        Case nonPelayo = getNonPelayoCase();
        Map<Id, Case> newMap = new Map<Id, Case>{ nonPelayo.Id => nonPelayo };

        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;

        Test.startTest();
        PelayoUpdateClaimTriggerLogic.processCases(newMap, null, true, false);
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(0, queued,
            'Non-Pelayo case must not be enqueued');
    }

    @IsTest
    static void processCases_updateNoChange_skipsEnqueue() {
        Case c = getPelayoCase();
        Case sameOld = c.clone(true, true, true, true);
        Map<Id, Case> newMap = new Map<Id, Case>{ c.Id => c };
        Map<Id, Case> oldMap = new Map<Id, Case>{ sameOld.Id => sameOld };

        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;

        Test.startTest();
        PelayoUpdateClaimTriggerLogic.processCases(newMap, oldMap, false, true);
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(0, queued,
            'Update with no relevant change should not enqueue');
    }

    @IsTest
    static void processCases_updateWithRelevantChange_enqueues() {
        Case c = getPelayoCase();
        Case oldC = c.clone(true, true, true, true);
        oldC.Subject = 'Old subject — different';
        Map<Id, Case> newMap = new Map<Id, Case>{ c.Id => c };
        Map<Id, Case> oldMap = new Map<Id, Case>{ oldC.Id => oldC };

        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;

        Test.startTest();
        PelayoUpdateClaimTriggerLogic.processCases(newMap, oldMap, false, true);
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'Update with a relevant field change should enqueue');
    }

    // ─── processCaseIds ──────────────────────────────────────────────────────

    @IsTest
    static void processCaseIds_bypass_returnsEarly() {
        Case c = getPelayoCase();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = true;

        Test.startTest();
        PelayoUpdateClaimTriggerLogic.processCaseIds(new Set<Id>{ c.Id });
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(0, queued, 'Bypass should skip processCaseIds');
    }

    @IsTest
    static void processCaseIds_nullOrEmpty_returnsEarly() {
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;

        Test.startTest();
        PelayoUpdateClaimTriggerLogic.processCaseIds(null);
        PelayoUpdateClaimTriggerLogic.processCaseIds(new Set<Id>());
        Test.stopTest();

        System.assertEquals(0, Limits.getQueueableJobs(), 'Null/empty input should be a no-op');
    }

    @IsTest
    static void processCaseIds_integrationUser_skipsEnqueue() {
        Case c = getPelayoCase();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = true;

        Test.startTest();
        PelayoUpdateClaimTriggerLogic.processCaseIds(new Set<Id>{ c.Id });
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(0, queued,
            'Integration user must NOT trigger related-object callouts');
    }

    @IsTest
    static void processCaseIds_normalUser_enqueues() {
        Case c = getPelayoCase();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;

        Test.startTest();
        PelayoUpdateClaimTriggerLogic.processCaseIds(new Set<Id>{ c.Id });
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'Non-integration user should enqueue the updateClaim Queueable');
    }

    // ─── Sharing (without sharing) ───────────────────────────────────────────

    @IsTest
    static void processCases_runAsStandardUser_executes() {
        Case c = getPelayoCase();
        Map<Id, Case> newMap = new Map<Id, Case>{ c.Id => c };

        Profile p = [
            SELECT Id FROM Profile
            WHERE UserLicense.Name = 'Salesforce' AND Name != 'System Administrator'
            LIMIT 1
        ];
        User u = new User(
            Alias = 'trigstd',
            Email = 'trigsharing@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TrigSharing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'trigsharing_' + System.currentTimeMillis() + '@example.com.test'
        );
        insert u;

        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;

        Test.startTest();
        System.runAs(u) {
            PelayoUpdateClaimTriggerLogic.processCases(newMap, null, true, false);
        }
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'without sharing class should enqueue regardless of running user record access');
    }
}
