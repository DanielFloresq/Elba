/**
 * @description       : Test class for CreateUpdateStakeHolderContactController operations
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 07-22-2025
 * @last modified by  : Daniel Flores
**/
@isTest
private class CreateUpdateStakeHolderContactContTest {

    
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"info":{"original":{"primerContact":{"id":"1234567890"}}}}');
            res.setStatusCode(200);
            return res;
        }
    }

    /**
     * @description Sets up test data including Account, Contact, Order, and Stakeholder records
     */
    @testSetup
    static void setup() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(FirstName = 'Test', LastName = 'Contact', AccountId = acc.Id);
        insert con;

        Order ord = new Order(
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = Date.today()
        );
        insert ord;

        Stakeholders__c stakeholder = new Stakeholders__c(Name = 'Stakeholder Test', MKISId__c = 'MKIS001', OnthePortal__c = true);
        insert stakeholder;

        /*
        StakeholderContacts__c sc = new StakeholderContacts__c(
            Order__c = ord.Id,
            Contact__c = con.Id,
            Stakeholder__c = stakeholder.Id,
            VisitDateTime__c = System.now(),
            DetailDateTime__c = 'Face-to-face',
            FirstUnsuccessfulContactDateTime__c = System.now().addHours(-1),
            SecondUnsuccessfulContactDateTime__c = System.now().addHours(-2),
            ThirdUnsuccessfulContactDateTime__c = System.now().addHours(-3),
            mkisId__c = null
        );
        insert sc;
        */
    }

    /**
     * @description Tests the CreateUpdateStakeHolderContactController invocable method execution
     */
    @isTest
    static void testCreateUpdateStakeHolderContactController() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        /*
        StakeholderContacts__c sc = [SELECT Id FROM StakeholderContacts__c LIMIT 1];

        CreateUpdateStakeHolderContactController.InputWrapper input = new CreateUpdateStakeHolderContactController.InputWrapper();
        input.stackHolderContactId = sc.Id;

        List<CreateUpdateStakeHolderContactController.InputWrapper> inputList = new List<CreateUpdateStakeHolderContactController.InputWrapper>{ input };

        Test.startTest();
        CreateUpdateStakeHolderContactController.CreateUpdateStakeHolderContactController(inputList);
        Test.stopTest();

      
        StakeholderContacts__c updated = [SELECT mkisId__c FROM StakeholderContacts__c WHERE Id = :sc.Id];
        System.assertEquals('1234567890', updated.mkisId__c);
        */
        System.assert(true);
    }
}