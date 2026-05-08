/**
 * @description       : Tests for PelayoUpdateClaimTriggerHandler.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 10-03-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
private class PelayoUpdateClaimTriggerHandlerTest {

    /**
     * @description Creates shared test data for all test methods, including an Account and a Contact.
     */
    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Pelayo UpdateClaim Test Account');
        insert acc;

        Contact con = new Contact(
            LastName = 'Pelayo Contact',
            AccountId = acc.Id,
            Email = 'pelayo.test@example.com'
        );
        insert con;
    }

    /**
     * @description Retrieves the Id of the test Account created in setupData.
     * @return Id of the test Account.
     */
    private static Id getAccountId() {
        return [SELECT Id FROM Account WHERE Name = 'Pelayo UpdateClaim Test Account' LIMIT 1].Id;
    }

    /**
     * @description Retrieves the Id of the test Contact created in setupData.
     * @return Id of the test Contact.
     */
    private static Id getContactId() {
        return [SELECT Id FROM Contact WHERE LastName = 'Pelayo Contact' LIMIT 1].Id;
    }

    /**
     * @description Builds a Case record with the specified subject and GrandAccount code.
     * @param subject The Case subject.
     * @param grandAccount The GrandAccount__c value (e.g. 'PLYO').
     * @return A new Case instance (not yet inserted).
     */
    private static Case buildCase(String subject, String grandAccount) {
        return new Case(
            Subject = subject,
            Status = 'New',
            Origin = 'Phone',
            GrandAccount__c = grandAccount,
            AccountId = getAccountId(),
            ContactId = getContactId()
        );
    }

    /**
     * @description Verifies that inserting a Pelayo Case enqueues an updateClaim Queueable job.
     */
    @IsTest
    static void testAfterInsert_PelayoCase_EnqueuesQueueable() {
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;

        Test.startTest();
        insert buildCase('Pelayo Insert Case', 'PLYO');
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM AsyncApexJob],
            'A inserção de um Case Pelayo deve enfileirar um job de updateClaim.'
        );
    }

    /**
     * @description Verifies that updating a relevant field on a Pelayo Case enqueues an updateClaim Queueable job.
     */
    @IsTest
    static void testAfterUpdate_RelevantFieldChanged_EnqueuesQueueable() {
        Case testCase = buildCase('Pelayo Update Case', 'PLYO');
        insert testCase;

        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;

        Test.startTest();
        testCase.Subject = 'Pelayo Update Case Changed';
        update testCase;
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM AsyncApexJob],
            'A alteração de um campo relevante deve enfileirar um job de updateClaim.'
        );
    }

    /**
     * @description Verifies that updating a non-relevant field on a Pelayo Case does not enqueue a Queueable job.
     */
    @IsTest
    static void testAfterUpdate_NonRelevantField_DoesNotEnqueueQueueable() {
        Case testCase = buildCase('Pelayo Non Relevant Update', 'PLYO');
        insert testCase;

        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;

        Test.startTest();
        testCase.Status = 'Working';
        update testCase;
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM AsyncApexJob],
            'A alteração de um campo não relevante não deve enfileirar jobs.'
        );
    }

    /**
     * @description Verifies that inserting a non-Pelayo Case does not enqueue a Queueable job.
     */
    @IsTest
    static void testAfterInsert_NonPelayoCase_DoesNotEnqueueQueueable() {
        PelayoUpdateClaimTriggerLogic.bypassExternalActions = false;

        Test.startTest();
        insert buildCase('Non Pelayo Insert Case', 'SLA');
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM AsyncApexJob],
            'Um Case que não seja Pelayo não deve enfileirar jobs.'
        );
    }
}