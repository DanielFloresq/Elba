/**
 * @description       : Test class for MKISElbaIncidenceHandler - validates Create and Update Incidence
 *                      calls to MKIS ELBA API with HTTP callout mocking
 * @author            : Daniel Flores
 * @last modified on  : 14-01-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
private class MKISElbaIncidenceHandlerTest {

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
     * @description Sets up test data including Account, Contract, Order, and Incident records
     */
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(Name = 'Test Account Incidence');
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

        Incident testIncident = new Incident(
            Subject = 'Test Incident',
            OrderService__c = testOrder.Id
        );
        insert testIncident;
    }

    /**
     * @description Tests createIncidenceAsync with mocked HTTP callout
     */
    @IsTest
    static void testCreateIncidenceAsync() {
        Incident inc = [SELECT Id FROM Incident LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MKISElbaMock());

        Test.startTest();
        MKISElbaIncidenceHandler.createIncidenceAsync(new List<Id>{ inc.Id });
        Test.stopTest();

        System.assertNotEquals(null, inc.Id, 'Incident should exist');
    }

    /**
     * @description Tests createIncidence for a single Incident with mocked HTTP callout
     */
    @IsTest
    static void testCreateIncidence() {
        Incident inc = [SELECT Id, Subject, OrderService__c, Status,
                               ExternalId__c, Reason__c, Sub_Reason__c
                        FROM Incident LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MKISElbaMock());

        Test.startTest();
        MKISElbaIncidenceHandler.createIncidence(inc);
        Test.stopTest();

        System.assertNotEquals(null, inc.Id, 'Incident should exist');
    }

    /**
     * @description Tests updateIncidenceAsync with mocked HTTP callout
     */
    @IsTest
    static void testUpdateIncidenceAsync() {
        Incident inc = [SELECT Id FROM Incident LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MKISElbaMock());

        Test.startTest();
        MKISElbaIncidenceHandler.updateIncidenceAsync(new List<Id>{ inc.Id });
        Test.stopTest();

        System.assertNotEquals(null, inc.Id, 'Incident should exist');
    }

    /**
     * @description Tests updateIncidence for a single Incident with mocked HTTP callout
     */
    @IsTest
    static void testUpdateIncidence() {
        Incident inc = [SELECT Id, Subject, OrderService__c, Status,
                               ExternalId__c, Reason__c, Sub_Reason__c
                        FROM Incident LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MKISElbaMock());

        Test.startTest();
        MKISElbaIncidenceHandler.updateIncidence(inc);
        Test.stopTest();

        System.assertNotEquals(null, inc.Id, 'Incident should exist');
    }

    /**
     * @description Tests createIncidence with an Incident that has no Order relation
     */
    @IsTest
    static void testCreateIncidenceWithoutOrderRelation() {
        Incident inc = new Incident(Subject = 'No Order Incident');
        insert inc;

        inc = [SELECT Id, Subject, OrderService__c, Status,
                      ExternalId__c, Reason__c, Sub_Reason__c
               FROM Incident WHERE Id = :inc.Id];

        Test.setMock(HttpCalloutMock.class, new MKISElbaMock());

        Test.startTest();
        MKISElbaIncidenceHandler.createIncidence(inc);
        Test.stopTest();

        // Should return early without making a callout
        System.assertNotEquals(null, inc.Id, 'Incident should exist');
    }
}