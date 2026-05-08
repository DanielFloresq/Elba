/**
 * @description       : Test factory utility for creating common test data records
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 06-03-2026
 * @last modified by  : Afonso Duque
**/
@isTest
public class TestFactory {

    /**
     * @description Creates and inserts an Account record with the specified name, email, phone, type, and guilds.
     * @param name The Account name.
     * @param email The Account email address.
     * @param phone The Account phone number.
     * @param type The Account type.
     * @param guilds The Account guild value.
     * @return The inserted Account record.
     */
    public static Account createAccount(String name, String email, String phone, String type, String guilds) {
        Account acc = new Account(
            Name = name,
            Email__c = email,
            Phone = phone,
            Type = type,
            Guild__c = guilds
        );
        insert acc;
        return acc;
    }

    /**
     * @description Creates and inserts an Account record with the specified name, type, guilds, and record type developer name.
     * @param name The Account name.
     * @param type The Account type.
     * @param guilds The Account guild value.
     * @param recordTypeDeveloperName The developer name of the record type to assign.
     * @return The inserted Account record.
     */
    public static Account createAccount(String name, String type, String guilds, String recordTypeDeveloperName) {
        Account acc = new Account(
            Name = name,
            Type = type,
            Guild__c = guilds,
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(recordTypeDeveloperName).getRecordTypeId()
        );
        insert acc;
        return acc;
    }

    /**
     * @description Creates and inserts a Case record with the specified account ID, status, and grand account.
     * @param accId The parent Account ID.
     * @param status The Case status.
     * @param granAccount The GrandAccount__c value.
     * @return The inserted Case record.
     */
    public static Case createCase(String accId, String status, String granAccount) {
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = status,
            Origin = 'Phone',
            GrandAccount__c = granAccount
        );
        insert testCase;
        return testCase;
    }

    /**
     * @description Creates and inserts an Order record with associated Product, PricebookEntry, and OrderItem.
     * @param caseId The related Case ID.
     * @param accId The parent Account ID.
     * @param status The Order status.
     * @return The inserted Order record.
     */
    public static Order createOrder(String caseId, String accId, String status) {
        Id standardPricebookId = Test.getStandardPricebookId();
        Order testOrder = new Order(
            AccountId = accId,
            Status = status,
            ChargeIdentifier__c = '',
            CaseNumber__c = caseId,
            EffectiveDate = Date.today(),
            Pricebook2Id = standardPricebookId
        );
        insert testOrder;

        Product2 testProduct = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert testProduct;

        PricebookEntry testPricebookEntry = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = testProduct.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert testPricebookEntry;

        OrderItem testOrderItem = new OrderItem(
            OrderId = testOrder.Id,
            PricebookEntryId = testPricebookEntry.Id,
            Quantity = 1,
            UnitPrice = 1
        );
        insert testOrderItem;

        return testOrder;
    }
}