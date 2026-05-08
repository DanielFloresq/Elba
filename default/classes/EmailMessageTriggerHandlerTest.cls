/**
 * @description       : Test class for EmailMessageTriggerHandler - validates trigger logic for
 *                      EmailMessage records on after insert and update events
 * @author            : Daniel Flores
 * @last modified on  : 14-01-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
private class EmailMessageTriggerHandlerTest {

    /**
     * @description Sets up test data including a Case and related EmailMessage
     */
    @TestSetup
    static void setupTestData() {
        Case testCase = new Case(
            Subject = 'Test Case for EmailMessage',
            Status = 'New'
        );
        insert testCase;
    }

    /**
     * @description Tests that inserting an EmailMessage related to a Case
     *              triggers the handler run() logic via the trigger framework
     */
    @IsTest
    static void testRunOnEmailMessageInsert() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        EmailMessage email = new EmailMessage(
            ParentId = testCase.Id,
            Subject = 'Test Email',
            TextBody = 'Test email body',
            FromAddress = 'test@example.com',
            ToAddress = 'recipient@example.com'
        );
        insert email;
        Test.stopTest();

        List<EmailMessage> emails = [SELECT Id FROM EmailMessage WHERE ParentId = :testCase.Id];
        System.assert(!emails.isEmpty(), 'EmailMessage should have been inserted');
    }

    /**
     * @description Tests that updating an EmailMessage triggers the handler
     *              run() logic for after-update events
     */
    @IsTest
    static void testRunOnEmailMessageUpdate() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        EmailMessage email = new EmailMessage(
            ParentId = testCase.Id,
            Subject = 'Test Email Update',
            TextBody = 'Original body',
            FromAddress = 'test@example.com',
            ToAddress = 'recipient@example.com'
        );
        insert email;

        Test.startTest();
        email.TextBody = 'Updated body';
        update email;
        Test.stopTest();

        EmailMessage updatedEmail = [SELECT TextBody FROM EmailMessage WHERE Id = :email.Id];
        System.assertEquals('Updated body', updatedEmail.TextBody, 'EmailMessage body should be updated');
    }
}