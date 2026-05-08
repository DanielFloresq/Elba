/**
 * @description       : Test class for ContentDocumentLinkTriggerHandler - validates trigger logic for
 *                      ContentDocumentLink records linked to Orders
 * @author            : Daniel Flores
 * @last modified on  : 14-01-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
private class ContentDocumentLinkTriggerHandlerTest {

    /**
     * @description Sets up test data including an Account, Contract, Order,
     *              and a ContentVersion/ContentDocument for linking
     */
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(Name = 'Test Account CDL');
        insert testAccount;

        Contract testContract = new Contract(
            AccountId = testAccount.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 12
        );
        insert testContract;

        Order testOrder = new Order(
            AccountId = testAccount.Id,
            ContractId = testContract.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert testOrder;

        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'TestDoc.pdf',
            VersionData = Blob.valueOf('Test file content')
        );
        insert cv;
    }

    /**
     * @description Tests that inserting a ContentDocumentLink linked to an Order
     *              triggers the handler run() logic without errors
     */
    @IsTest
    static void testRunOnContentDocumentLinkInsert() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1];

        Test.startTest();
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = testOrder.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V'
        );
        insert cdl;
        Test.stopTest();

        // Scaffolding assertion — verify record was created
        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :testOrder.Id
        ];
        System.assert(!links.isEmpty(), 'ContentDocumentLink should be created for the Order');
    }
}