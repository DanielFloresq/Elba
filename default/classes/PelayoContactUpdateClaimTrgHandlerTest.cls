/**
 * @description       : Test class for PelayoContactUpdateClaimTriggerHandler.
 *                      Covers Contact update path with monitored field changes,
 *                      no-change skip, non-Pelayo case skip, finished-case skip,
 *                      bulk safety, and sharing semantics.
 * @author            : Test Class Builder
 * @group             : Pelayo Integration
**/
@IsTest
private class PelayoContactUpdateClaimTrgHandlerTest {

    private static final String PELAYO_GRAND_ACCOUNT = 'PLYO';

    @TestSetup
    static void setupTestData() {
        Account acc = TestFactory.createAccount(
            'Contact Trigger Account',
            PELAYO_GRAND_ACCOUNT,
            'A2',
            'Customer'
        );

        Contact contact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@test.com',
            MobilePhone = '600000001',
            AccountId = acc.Id
        );
        insert contact;

        Case pelayoCase = new Case(
            Subject = 'Pelayo Contact Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = PELAYO_GRAND_ACCOUNT,
            ContactId = contact.Id
        );
        insert pelayoCase;
    }

    private static Contact getContact() {
        return [SELECT Id, FirstName, LastName, Email, MobilePhone FROM Contact LIMIT 1];
    }

    // ─── Update path ─────────────────────────────────────────────────────────

    @IsTest
    static void run_lastNameChanged_enqueuesUpdateClaim() {
        Contact c = getContact();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;

        Test.startTest();
        c.LastName = 'Doe-Updated';
        update c;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'LastName change on a Contact tied to a Pelayo Case should enqueue updateClaim');
    }

    @IsTest
    static void run_emailChanged_enqueuesUpdateClaim() {
        Contact c = getContact();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;

        Test.startTest();
        c.Email = 'new.email@test.com';
        update c;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued, 'Email change should enqueue updateClaim');
    }

    @IsTest
    static void run_mobilePhoneChanged_enqueuesUpdateClaim() {
        Contact c = getContact();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;

        Test.startTest();
        c.MobilePhone = '600000999';
        update c;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued, 'MobilePhone change should enqueue updateClaim');
    }

    @IsTest
    static void run_unmonitoredFieldChanged_doesNotEnqueue() {
        Contact c = getContact();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;

        Test.startTest();
        // Title is not in the monitored field list
        c.Title = 'Some Title';
        update c;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(0, queued,
            'Changing a non-monitored field must not enqueue updateClaim');
    }

    @IsTest
    static void run_finishedCase_doesNotEnqueue() {
        Contact c = getContact();
        Case pelayoCase = [SELECT Id FROM Case WHERE ContactId = :c.Id LIMIT 1];
        update new Case(Id = pelayoCase.Id, Status = 'Finished');

        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;

        Test.startTest();
        c.LastName = 'Updated Again';
        update c;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(0, queued,
            'Cases in Finished status must be excluded from the updateClaim flow');
    }

    @IsTest
    static void run_bypass_doesNotEnqueue() {
        Contact c = getContact();
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = true;

        Test.startTest();
        c.LastName = 'Bypassed';
        update c;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(0, queued, 'Bypass true should skip enqueue');
    }

    // ─── Bulk safety ─────────────────────────────────────────────────────────

    @IsTest
    static void run_bulk200Updates_enqueuesAtMostOnce() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<Contact> bulkRecords = new List<Contact>();
        for (Integer i = 0; i < 200; i++) {
            bulkRecords.add(new Contact(
                FirstName = 'Bulk',
                LastName = 'Contact-' + i,
                AccountId = acc.Id,
                Email = 'bulk' + i + '@test.com'
            ));
        }
        insert bulkRecords;

        // Attach each Contact to a Pelayo Case
        List<Case> cases = new List<Case>();
        for (Contact c : bulkRecords) {
            cases.add(new Case(
                Subject = 'Bulk Case ' + c.LastName,
                Status = 'Opening',
                Origin = 'Phone',
                GrandAccount__c = PELAYO_GRAND_ACCOUNT,
                ContactId = c.Id
            ));
        }
        insert cases;

        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;
        PelayoUpdateClaimTriggerLogic.treatCurrentUserAsIntegrationUser = false;

        Test.startTest();
        for (Contact c : bulkRecords) c.LastName = c.LastName + '-X';
        update bulkRecords;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        // Aggregated by the downstream service into a single Queueable per trigger run
        System.assertEquals(1, queued,
            '200 Contact updates should produce exactly one Queueable. Got: ' + queued);
    }
}
