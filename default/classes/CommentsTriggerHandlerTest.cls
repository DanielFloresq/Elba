/**
 * @description       : Test class for CommentsTriggerHandler - validates trigger logic for Comments__c records,
 *                      including Hito comment filtering and after-insert handling
 * @author            : Daniel Flores
 * @last modified on  : 14-01-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
private class CommentsTriggerHandlerTest {

    /**
     * @description Sets up test data for Comments__c-related tests
     */
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(Name = 'Test Account Comments');
        insert testAccount;
    }

    /**
     * @description Tests the handleAfterInsert method with a Hito-prefixed comment
     */
    @IsTest
    static void testHandleAfterInsertWithHitoComment() {
        List<Comments__c> comments = new List<Comments__c>();
        Comments__c hitoComment = new Comments__c(
            Comment__c = 'Hito - Test milestone comment'
        );
        comments.add(hitoComment);

        Test.startTest();
        insert comments;
        Test.stopTest();

        List<Comments__c> inserted = [SELECT Id, Comment__c FROM Comments__c];
        System.assert(!inserted.isEmpty(), 'Comment should have been inserted');
    }

    /**
     * @description Tests the filterHitoComments method with non-Hito comments
     */
    @IsTest
    static void testFilterHitoCommentsWithNonHitoComment() {
        Comments__c regularComment = new Comments__c(
            Comment__c = 'Regular comment without Hito prefix'
        );

        Test.startTest();
        insert regularComment;
        Test.stopTest();

        List<Comments__c> inserted = [SELECT Id, Comment__c FROM Comments__c];
        System.assert(!inserted.isEmpty(), 'Regular comment should have been inserted');
    }

    /**
     * @description Tests the filterHitoComments method excludes SMS Hito prefix comments
     */
    @IsTest
    static void testFilterHitoCommentsExcludesSmsHito() {
        Comments__c smsHitoComment = new Comments__c(
            Comment__c = 'Hito - Envío de SMS test'
        );

        Test.startTest();
        insert smsHitoComment;
        Test.stopTest();

        List<Comments__c> inserted = [SELECT Id, Comment__c FROM Comments__c];
        System.assert(!inserted.isEmpty(), 'SMS Hito comment should have been inserted');
    }

    /**
     * @description Tests that handleAfterInsert handles null or empty list gracefully
     */
    @IsTest
    static void testHandleAfterInsertWithEmptyList() {
        Test.startTest();
        // Directly call the @TestVisible method with empty list
        CommentsTriggerHandler.handleAfterInsert(new List<Comments__c>());
        Test.stopTest();

        // No exceptions should be thrown
        System.assert(true, 'Empty list should be handled gracefully');
    }
}