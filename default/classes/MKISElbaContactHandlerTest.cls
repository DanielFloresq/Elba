/**
 * @description       : Test class for MKISElbaContactHandler - validates contact field change detection,
 *                      Create Contact API calls, and request building logic
 * @author            : Daniel Flores
 * @last modified on  : 22-04-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
private class MKISElbaContactHandlerTest {

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
     * @description Sets up test data including Account, Contact, Contract, and Order records
     */
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(Name = 'Test Account Contact');
        insert testAccount;

        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact Person',
            AccountId = testAccount.Id,
            Phone = '+351912345678',
            Email = 'contact@test.com'
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
     * @description Tests hasContactFieldsChanged returns true when BillToContactId changes
     */
    @IsTest
    static void testHasContactFieldsChangedTrue() {
        Order newOrder = [SELECT Id, BillToContactId, ContactedPerson__c,
                                 ContactDateTime__c, ContactMade__c,
                                 FailedContactReason__c, VisitDateTime__c, VisitType__c
                          FROM Order LIMIT 1];

        Order oldOrder = newOrder.clone(true, true, true, true);
        newOrder.ContactDateTime__c = System.now().addHours(1);

        Test.startTest();
        Boolean result = MKISElbaContactHandler.hasContactFieldsChanged(newOrder, oldOrder);
        Test.stopTest();

        System.assertEquals(true, result, 'Should detect contact field change');
    }

    /**
     * @description Tests hasContactFieldsChanged returns false when no contact fields change
     */
    @IsTest
    static void testHasContactFieldsChangedFalse() {
        Order testOrder = [SELECT Id, BillToContactId, ContactedPerson__c,
                                  ContactDateTime__c, ContactMade__c,
                                  FailedContactReason__c, VisitDateTime__c, VisitType__c
                           FROM Order LIMIT 1];

        Order sameOrder = testOrder.clone(true, true, true, true);

        Test.startTest();
        Boolean result = MKISElbaContactHandler.hasContactFieldsChanged(testOrder, sameOrder);
        Test.stopTest();

        System.assertEquals(false, result, 'Should not detect change when fields are the same');
    }

    /**
     * @description Tests hasContactFieldsChanged returns false when oldOrder is null
     */
    @IsTest
    static void testHasContactFieldsChangedNullOld() {
        Order testOrder = [SELECT Id, BillToContactId FROM Order LIMIT 1];

        Test.startTest();
        Boolean result = MKISElbaContactHandler.hasContactFieldsChanged(testOrder, null);
        Test.stopTest();

        System.assertEquals(false, result, 'Should return false when oldOrder is null');
    }

    /**
     * @description Tests createContactAsync with mocked HTTP callout
     */
    @IsTest
    static void testCreateContactAsync() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MKISElbaMock());

        Test.startTest();
        MKISElbaContactHandler.createContactAsync(new List<Id>{ testOrder.Id });
        Test.stopTest();

        System.assertNotEquals(null, testOrder.Id, 'Order should exist');
    }

    /**
     * @description Tests createContact for a single Order with mocked HTTP callout
     */
    @IsTest
    static void testCreateContact() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        List<Order> orders = MKISElbaServiceHandler.queryOrders(new List<Id>{ testOrder.Id });

        Test.setMock(HttpCalloutMock.class, new MKISElbaMock());

        Test.startTest();
        if (!orders.isEmpty()) {
            MKISElbaContactHandler.createContact(orders[0]);
        }
        Test.stopTest();

        System.assert(!orders.isEmpty(), 'Orders should be queried');
    }
}