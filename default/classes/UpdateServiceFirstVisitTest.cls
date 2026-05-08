/**
 * @description       : Test class for UpdateServiceFirstVisit service update operations
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 19-08-2025
 * @last modified by  : Daniel Flores
**/
@IsTest
private class UpdateServiceFirstVisitTest {

    
    private class ServiceFirstVisitMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"message":"Visit Integration Successful"}');
            return res;
        }
    }

    /**
     * @description Creates test Account, Contact, Case, Orders, and Stakeholder records for use in test methods.
     */
    @testSetup
    static void setupTestData() {
        Account acc = new Account(
            Name = 'Test Provider',
            TaxNumber__c = '123456789',
            Phone = '211234567',
            Email__c = 'provider@example.com'
        );
        insert acc;

        Contact contact = new Contact(
            LastName = 'Test Contact',
            PolicyNumber__c = '123456',
            MailingStreet = 'Rua Exemplo 123',
            MailingPostalCode = '1000-001',
            Phone = '211234567',
            MobilePhone = '911234567',
            Email = 'contact@example.com',
            IDNumber__c = '987654321',
            BuildingCapital__c = 100000,
            FillingCapital__c = 20000,
            LiabilityCapital__c = 50000
        );
        insert contact;

        Case testCase = new Case(
            Subject = 'Test Case',
            GrandAccount__c = 'SLA',
            GCOrderNumber__c = 'GC789',
            ClaimDate__c = Date.today(),
            Coverage__c = '1',
            Description = 'Danos causados por inundação'
        );
        insert testCase;

        Order ord = new Order(
            AccountId = acc.Id,
            BillToContactId = contact.Id,
            CaseNumber__c = testCase.Id,
            Type = 'Serviço Técnico',
            EffectiveDate = Date.today(),
            Status = 'Active'
        );
        insert ord;

        Order ord2 = new Order(
            AccountId = acc.Id,
            BillToContactId = contact.Id,
            CaseNumber__c = testCase.Id,
            Type = 'Serviço Standard',
            EffectiveDate = Date.today(),
            Status = 'Active'
        );
        insert ord2;

        Stakeholders__c stakeholder = new Stakeholders__c(
            OnThePortal__c = false,
            Case__c = testCase.Id
        );
        insert stakeholder;
    }



    /**
     * @description Verifies that UpdateServiceFirstVisit correctly calls the MKIS API and updates the Order integration fields.
     */
    @IsTest
    static void testUpdateServiceFirstVisit() {
       
        Order ord = [SELECT ID FROM ORDER LIMIT 1];

       

     
        Test.setMock(HttpCalloutMock.class, new ServiceFirstVisitMock());

        Test.startTest();
        // Invocar o método
        UpdateServiceFirstVisit.UpdateServiceFirstVisit(
            new List<String>{ ord.Id }
        );
        Test.stopTest();

        // Validar que o Order foi atualizado com a resposta
        Order updatedOrd = [
            SELECT LastIntegrationDescription__c, LastIntegrationDateTime__c
            FROM Order
            WHERE Id = :ord.Id
        ];
        System.assertEquals('Visit Integration Successful', updatedOrd.LastIntegrationDescription__c);
        System.assertNotEquals(null, updatedOrd.LastIntegrationDateTime__c);
    }
}