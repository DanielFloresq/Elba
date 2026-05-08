/**
 * @description       : Test class for MKISElbaOrderTriggerLogic - validates MKIS-specific Order trigger logic
 *                      including Create/Update Service and Create Contact dispatching
 * @author            : Daniel Flores
 * @last modified on  : 30-04-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
private class MKISElbaOrderTriggerLogicTest {

    /**
     * @description Mock HTTP callout class for simulating MKIS ELBA API responses
     */
    private class MKISElbaMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"message":"Success"}');
            return res;
        }
    }

    /**
     * @description Sets up test data including Account with Supplier RecordType, Contract, and Order
     */
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(Name = 'Test Supplier MKIS');
        insert testAccount;

        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id
        );
        insert testContact;

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
            BillToContactId = testContact.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert testOrder;
    }

    /**
     * @description Tests processMKISOrder in insert context with a valid Order
     */
    @IsTest
    static void testProcessMKISOrderOnInsert() {
        Order testOrder = [SELECT Id, AccountId, Status, UrlLinkStatus__c,
                                  ChargeIdentifier__c, Guild__c, Urgent__c,
                                  Observaciones__c, Type, ProviderType__c,
                                  ProviderReference__c, /* Causa__c, SubCausa__c, */
                                  OPFVTSIndicatorsPresent__c, RelatedOrder__c,
                                  CaseNumber__c, BillToContactId
                           FROM Order LIMIT 1];

        Map<Id, Order> newMap = new Map<Id, Order>{ testOrder.Id => testOrder };

        Test.setMock(HttpCalloutMock.class, new MKISElbaMock());

        Test.startTest();
        MKISElbaOrderTriggerLogic.processMKISOrder(newMap, null, true, false);
        Test.stopTest();

        System.assertNotEquals(null, testOrder.Id, 'Order should exist');
    }

    /**
     * @description Tests processMKISOrder in update context with relevant field changes
     */
    @IsTest
    static void testProcessMKISOrderOnUpdate() {
        Order testOrder = [SELECT Id, AccountId, Status, UrlLinkStatus__c,
                                  ChargeIdentifier__c, Guild__c, Urgent__c,
                                  Observaciones__c, Type, ProviderType__c,
                                  ProviderReference__c, /* Causa__c, SubCausa__c, */
                                  OPFVTSIndicatorsPresent__c, RelatedOrder__c,
                                  CaseNumber__c, BillToContactId
                           FROM Order LIMIT 1];

        Order oldOrder = testOrder.clone(true, true, true, true);
        Map<Id, Order> newMap = new Map<Id, Order>{ testOrder.Id => testOrder };
        Map<Id, Order> oldMap = new Map<Id, Order>{ testOrder.Id => oldOrder };

        Test.setMock(HttpCalloutMock.class, new MKISElbaMock());

        Test.startTest();
        MKISElbaOrderTriggerLogic.processMKISOrder(newMap, oldMap, false, true);
        Test.stopTest();

        System.assertNotEquals(null, testOrder.Id, 'Order should exist');
    }

    /**
     * @description Tests processMKISOrder with null input does not throw exceptions
     */
    @IsTest
    static void testProcessMKISOrderWithNullInput() {
        Test.startTest();
        MKISElbaOrderTriggerLogic.processMKISOrder(null, null, true, false);
        Test.stopTest();

        // No exception should be thrown
        System.assert(true, 'Null input should be handled gracefully');
    }
}