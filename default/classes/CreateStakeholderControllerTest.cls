/**
 * @description       : Test class for CreateStakeholderController stakeholder creation and update operations
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 19-08-2025
 * @last modified by  : Daniel Flores
**/
@IsTest
private class CreateStakeholderControllerTest {

    // Mock para simular o POST/PUT do serviço externo
    private class StakeholderMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"message":"Integration OK","data":{"id":"MKIS-9999"}}');
            return res;
        }
    }
    /**
     * @description Sets up test data including Account, Contact, Order, and Stakeholder records
     */
    @testSetup
    static void setup() {
        Test.setMock(HttpCalloutMock.class, new StakeholderMock());
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
     * @description Tests stakeholder creation via POST when isToCreateInNewService is true
     */
    @IsTest
    static void testCreateStakeholderPOST2() {
        // Criar Order
        Order ord = [SELECT ID FROM ORDER LIMIT 1];
        

        // Criar Stakeholder sem MKISId__c (para acionar create)
        Stakeholders__c sh = new Stakeholders__c(
            Name = 'Stakeholder Test',
            Description__c = 'Obs teste',
            Address__Street__s = 'Rua XPTO',
            Address__PostalCode__s = '1234-567',
            Address__City__s = 'Lisboa',
            Address__CountryCode__s = 'PT'
        );
        insert sh;

        // Criar input
        CreateStakeholderController.InputWrapper input = new CreateStakeholderController.InputWrapper();
        input.idOrder = ord.Id;
        input.idStakeHolder = sh.Id;
        input.idStakeHolderContact = 'contact-001';
        input.isForUpdate = false;
        input.isToCreateInNewService = true;

        Test.setMock(HttpCalloutMock.class, new StakeholderMock());

        Test.startTest();
        CreateStakeholderController.createStakeHolderFlowUtils(
            new List<CreateStakeholderController.InputWrapper>{ input }
        );
        Test.stopTest();

        // Validar atualização
        Stakeholders__c updated = [
            SELECT LastIntegrationDescription__c, LastIntegrationDateTime__c, MKISId__c, OnThePortal__c
            FROM Stakeholders__c
            WHERE Id = :sh.Id
        ];
        System.assertEquals('Integration OK', updated.LastIntegrationDescription__c);
        System.assertNotEquals(null, updated.LastIntegrationDateTime__c);
        System.assertEquals(true, updated.OnThePortal__c);
        System.assertEquals('MKIS-9999', updated.MKISId__c);
    }

    /**
     * @description Tests stakeholder creation via POST when isToCreateInNewService is false
     */
    @IsTest
    static void testCreateStakeholderPOST() {
        // Criar Order
        Order ord = [SELECT ID FROM ORDER LIMIT 1];
        

        // Criar Stakeholder sem MKISId__c (para acionar create)
        Stakeholders__c sh = new Stakeholders__c(
            Name = 'Stakeholder Test',
            Description__c = 'Obs teste',
            Address__Street__s = 'Rua XPTO',
            Address__PostalCode__s = '1234-567',
            Address__City__s = 'Lisboa',
            Address__CountryCode__s = 'PT'
        );
        insert sh;

        // Criar input
        CreateStakeholderController.InputWrapper input = new CreateStakeholderController.InputWrapper();
        input.idOrder = ord.Id;
        input.idStakeHolder = sh.Id;
        input.idStakeHolderContact = 'contact-001';
        input.isForUpdate = false;
        input.isToCreateInNewService = false;

        Test.setMock(HttpCalloutMock.class, new StakeholderMock());

        Test.startTest();
        CreateStakeholderController.createStakeHolderFlowUtils(
            new List<CreateStakeholderController.InputWrapper>{ input }
        );
        Test.stopTest();

        // Validar atualização
        Stakeholders__c updated = [
            SELECT LastIntegrationDescription__c, LastIntegrationDateTime__c, MKISId__c, OnThePortal__c
            FROM Stakeholders__c
            WHERE Id = :sh.Id
        ];
        System.assertEquals('Integration OK', updated.LastIntegrationDescription__c);
        System.assertNotEquals(null, updated.LastIntegrationDateTime__c);
        System.assertEquals(true, updated.OnThePortal__c);
        System.assertEquals('MKIS-9999', updated.MKISId__c);
    }

    /**
     * @description Tests stakeholder update via PUT when MKISId already exists
     */
    @IsTest
    static void testUpdateStakeholderPUT() {
        // Criar Order
        Order ord = [SELECT ID FROM ORDER LIMIT 1];

        // Criar Stakeholder já com MKISId__c (para acionar update)
        Stakeholders__c sh = new Stakeholders__c(
            Name = 'Stakeholder Update',
            Description__c = 'Obs update',
            MKISId__c = 'MKIS-EXISTE',
            Address__Street__s = 'Rua Beta',
            Address__City__s = 'Porto'
        );
        insert sh;

        // Criar input
        CreateStakeholderController.InputWrapper input = new CreateStakeholderController.InputWrapper();
        input.idOrder = ord.Id;
        input.idStakeHolder = sh.Id;
        input.idStakeHolderContact = 'contact-002';
        input.isForUpdate = true;
        input.isToCreateInNewService = false;

        Test.setMock(HttpCalloutMock.class, new StakeholderMock());

        Test.startTest();
        CreateStakeholderController.createStakeHolderFlowUtils(
            new List<CreateStakeholderController.InputWrapper>{ input }
        );
        Test.stopTest();

        // Validar atualização
        Stakeholders__c updated = [
            SELECT LastIntegrationDescription__c, LastIntegrationDateTime__c, OnThePortal__c
            FROM Stakeholders__c
            WHERE Id = :sh.Id
        ];
        System.assertEquals('Integration OK', updated.LastIntegrationDescription__c);
        System.assertNotEquals(null, updated.LastIntegrationDateTime__c);
        System.assertEquals(true, updated.OnThePortal__c);
    }
}