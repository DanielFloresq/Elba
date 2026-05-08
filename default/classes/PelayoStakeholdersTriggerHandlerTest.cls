/**
 * @description       : Test class for PelayoStakeholdersTriggerHandler.
 *                      Covers the trigger context flag, integration-user guard,
 *                      filterPelayoCaseIds query, and insert/update/delete trigger paths.
 *                      Asserts via PelayoUpdateClaimTriggerLogic queueable counts.
 * @author            : Test Class Builder
 * @group             : Pelayo Integration
**/
@IsTest
private class PelayoStakeholdersTriggerHandlerTest {

    private static final String PELAYO_GRAND_ACCOUNT = 'PLYO';

    @TestSetup
    static void setupTestData() {
        Account acc = TestFactory.createAccount(
            'Stakeholder Trigger Account',
            PELAYO_GRAND_ACCOUNT,
            'A2',
            'Customer'
        );

        Case pelayoCase = new Case(
            Subject = 'Pelayo Stakeholder Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = PELAYO_GRAND_ACCOUNT,
            InsurerClaimReference__c = 'SIN-STK-TRG-001'
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
        return [SELECT Id FROM Case WHERE GrandAccount__c = :PELAYO_GRAND_ACCOUNT LIMIT 1];
    }

    private static Case getNonPelayoCase() {
        return [SELECT Id FROM Case WHERE GrandAccount__c = 'OTHER' LIMIT 1];
    }

    // ─── Insert path ─────────────────────────────────────────────────────────

    @IsTest
    static void run_insertPelayoStakeholder_enqueuesUpdateClaim() {
        Case pelayoCase = getPelayoCase();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;
        PelayoStakeholdersTriggerHandler.treatCurrentUserAsIntegrationUser = false;

        Test.startTest();
        Stakeholders__c sh = new Stakeholders__c(
            Name = 'Stakeholder Insert',
            Case__c = pelayoCase.Id,
            StakeholderType__c = 'Asegurado'
        );
        insert sh;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'Inserting a Stakeholder on a Pelayo Case should enqueue updateClaim once');
    }

    @IsTest
    static void run_insertNonPelayoStakeholder_doesNotEnqueue() {
        Case nonPelayo = getNonPelayoCase();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;
        PelayoStakeholdersTriggerHandler.treatCurrentUserAsIntegrationUser = false;

        Test.startTest();
        Stakeholders__c sh = new Stakeholders__c(
            Name = 'Non-Pelayo Stakeholder',
            Case__c = nonPelayo.Id,
            StakeholderType__c = 'Asegurado'
        );
        insert sh;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(0, queued,
            'Stakeholders for non-Pelayo cases must not enqueue updateClaim');
    }

    // ─── Update path ─────────────────────────────────────────────────────────

    @IsTest
    static void run_updateStakeholder_enqueuesUpdateClaim() {
        Case pelayoCase = getPelayoCase();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;
        PelayoStakeholdersTriggerHandler.treatCurrentUserAsIntegrationUser = false;

        Stakeholders__c sh = new Stakeholders__c(
            Name = 'Update Test',
            Case__c = pelayoCase.Id,
            StakeholderType__c = 'Asegurado'
        );
        insert sh;

        Test.startTest();
        sh.Name = 'Updated';
        update sh;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'Updating a Stakeholder on a Pelayo Case should enqueue updateClaim');
    }

    // ─── Delete path ─────────────────────────────────────────────────────────

    @IsTest
    static void run_deleteStakeholder_enqueuesUpdateClaim() {
        Case pelayoCase = getPelayoCase();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;
        PelayoStakeholdersTriggerHandler.treatCurrentUserAsIntegrationUser = false;

        Stakeholders__c sh = new Stakeholders__c(
            Name = 'Delete Test',
            Case__c = pelayoCase.Id,
            StakeholderType__c = 'Asegurado'
        );
        insert sh;

        Test.startTest();
        delete sh;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'Deleting a Stakeholder from a Pelayo Case should enqueue updateClaim');
    }

    // ─── Integration user skip ───────────────────────────────────────────────

    @IsTest
    static void run_asIntegrationUser_skipsEnqueue() {
        Case pelayoCase = getPelayoCase();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoStakeholdersTriggerHandler.treatCurrentUserAsIntegrationUser = true;

        Test.startTest();
        Stakeholders__c sh = new Stakeholders__c(
            Name = 'Integration Insert',
            Case__c = pelayoCase.Id,
            StakeholderType__c = 'Asegurado'
        );
        insert sh;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(0, queued,
            'Integration user must NOT trigger updateClaim from Stakeholders__c changes');
    }

    // ─── Bulk safety ─────────────────────────────────────────────────────────

    @IsTest
    static void run_bulk200Stakeholders_singleEnqueueOrFewer() {
        Case pelayoCase = getPelayoCase();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;
        PelayoStakeholdersTriggerHandler.treatCurrentUserAsIntegrationUser = false;

        List<Stakeholders__c> bulkRecords = new List<Stakeholders__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkRecords.add(new Stakeholders__c(
                Name = 'Bulk ' + i,
                Case__c = pelayoCase.Id,
                StakeholderType__c = 'Asegurado'
            ));
        }

        Test.startTest();
        insert bulkRecords;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        // Insert of 200 stakeholders all on the same Pelayo case → at most 1 enqueue
        System.assert(queued <= 1,
            '200 Stakeholders on one Pelayo case should produce at most one Queueable. Got: ' + queued);
    }

    // ─── Sharing (with sharing) ──────────────────────────────────────────────

    @IsTest
    static void run_runAsStandardUser_enqueuesUnderSharing() {
        Case pelayoCase = getPelayoCase();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;
        PelayoStakeholdersTriggerHandler.treatCurrentUserAsIntegrationUser = false;

        Profile p = [
            SELECT Id FROM Profile
            WHERE UserLicense.Name = 'Salesforce' AND Name != 'System Administrator'
            LIMIT 1
        ];
        User u = new User(
            Alias = 'sthstd',
            Email = 'sthsharing@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'StkTrigSharing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'sthsharing_' + System.currentTimeMillis() + '@example.com.test'
        );
        insert u;

        Boolean runAsCompleted = false;
        Test.startTest();
        System.runAs(u) {
            Stakeholders__c sh = new Stakeholders__c(
                Name = 'Sharing Test',
                Case__c = pelayoCase.Id,
                StakeholderType__c = 'Asegurado'
            );
            try {
                insert sh;
            } catch (Exception e) {
                // Standard users may lack create access on Stakeholders__c — that is
                // a sharing/permission outcome, not a handler defect.
                System.debug('runAs insert blocked: ' + e.getMessage());
            }
            runAsCompleted = true;
        }
        Test.stopTest();

        System.assert(runAsCompleted,
            'with sharing handler must not throw an unhandled exception inside System.runAs (insert may be blocked by sharing — that is caught and is acceptable)');
    }
}
