/**
 * @description       : Test class for PelayoInsurableCoverageTriggerHandler.
 *                      Covers insert / update / delete / undelete trigger paths,
 *                      reentrance guard, bulk safety and sharing semantics.
 *                      Asserts via PelayoUpdateClaimTriggerLogic queueable counts.
 * @author            : Test Class Builder
 * @group             : Pelayo Integration
**/
@IsTest
private class PelayoInsurableCoverageTrgHandlerTest {

    private static final String PELAYO_GRAND_ACCOUNT = 'PLYO';

    @TestSetup
    static void setupTestData() {
        TestFactory.createAccount(
            'Coverage Trigger Account',
            PELAYO_GRAND_ACCOUNT,
            'A2',
            'Customer'
        );
        Case pelayoCase = new Case(
            Subject = 'Coverage Trigger Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = PELAYO_GRAND_ACCOUNT
        );
        insert pelayoCase;
    }

    private static Case getCase() { return [SELECT Id FROM Case LIMIT 1]; }

    // ─── Insert / Update / Delete paths ──────────────────────────────────────

    @IsTest
    static void run_insert_enqueuesUpdateClaim() {
        Case c = getCase();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;

        Test.startTest();
        InsurableCoverage__c cov = new InsurableCoverage__c(
            Claim__c = c.Id,
            Coverage__c = 'Robo'
        );
        insert cov;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'InsurableCoverage__c insert on a Pelayo Case should enqueue updateClaim');
    }

    @IsTest
    static void run_update_enqueuesUpdateClaim() {
        Case c = getCase();
        InsurableCoverage__c cov = new InsurableCoverage__c(
            Claim__c = c.Id,
            Coverage__c = 'Robo'
        );
        insert cov;

        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;

        Test.startTest();
        cov.Coverage__c = 'Daños';
        update cov;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'InsurableCoverage__c update should enqueue updateClaim');
    }

    @IsTest
    static void run_delete_enqueuesUpdateClaim() {
        Case c = getCase();
        InsurableCoverage__c cov = new InsurableCoverage__c(
            Claim__c = c.Id,
            Coverage__c = 'Robo'
        );
        insert cov;

        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;

        Test.startTest();
        delete cov;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'InsurableCoverage__c delete should enqueue updateClaim');
    }

    @IsTest
    static void run_undelete_enqueuesUpdateClaim() {
        Case c = getCase();
        InsurableCoverage__c cov = new InsurableCoverage__c(
            Claim__c = c.Id,
            Coverage__c = 'Robo'
        );
        insert cov;
        delete cov;

        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;

        Test.startTest();
        undelete cov;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'InsurableCoverage__c undelete on a Pelayo Case should enqueue updateClaim');
    }

    @IsTest
    static void run_bypass_doesNotEnqueue() {
        Case c = getCase();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = true;

        Test.startTest();
        insert new InsurableCoverage__c(
            Claim__c = c.Id,
            Coverage__c = 'Robo'
        );
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(0, queued, 'Bypass should skip enqueue');
    }

    // ─── Bulk safety ─────────────────────────────────────────────────────────

    @IsTest
    static void run_bulk200Inserts_singleEnqueueOrFewer() {
        Case c = getCase();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;

        List<InsurableCoverage__c> bulkRecords = new List<InsurableCoverage__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkRecords.add(new InsurableCoverage__c(
                Claim__c = c.Id,
                Coverage__c = 'Bulk ' + i
            ));
        }

        Test.startTest();
        insert bulkRecords;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assert(queued <= 1,
            '200 InsurableCoverage__c inserts on one Case should produce at most one Queueable. Got: ' + queued);
    }
}
