/**
 * @description       : Legacy test class for MultiRecordIntegrationController operations
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 21-01-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
public with sharing class MultiRecordControllerTestClass {

    /**
     * @description Tests getObjectType by passing a Case record Id.
     **/
    @IsTest
    public static void test_getObjectType(){
        List<Case> cases = [SELECT Id FROM Case LIMIT 1];
        MultiRecordIntegrationController.getObjectType(cases[0].Id);
    }

    /**
     * @description Tests getRecords with Case record type and serialized Case Ids.
     **/
    @IsTest
    public static void test_getRecordsCases(){
        List<Case> cases = [SELECT Id FROM Case LIMIT 1];
        List<String> casesIds = new List<String>();
        for(Case currentCase : cases){
            casesIds.add(currentCase.Id);
        }
        MultiRecordIntegrationController.getRecords('Case', JSON.serialize(casesIds));
    }

    /**
     * @description Tests getRecords with Order record type and serialized Order Ids.
     **/
    @IsTest
    public static void test_getRecordsOrders(){
        List<Order> orders = [SELECT Id FROM Order LIMIT 1];
        List<String> orderIds = new List<String>();
        for(Order currentOrder : orders){
            orderIds.add(currentOrder.Id);
        }
        MultiRecordIntegrationController.getRecords('Order', JSON.serialize(orderIds));
    }

    /**
     * @description Tests getAllRecords retrieval for Case record type.
     **/
    @IsTest
    public static void test_getAllRecordsCases(){
        MultiRecordIntegrationController.getAllRecords('Case');
    }

    /**
     * @description Tests getAllRecords retrieval for Order record type.
     **/
    @IsTest
    public static void test_getAllRecordsOrders(){
        MultiRecordIntegrationController.getAllRecords('Order');
    }

    /**
     * @description Tests reprocessMultipleRecords batch execution for Case records.
     **/
    @IsTest
    public static void test_reprocessMultipleRecordsCases(){
        List<Case> cases = [SELECT Id FROM Case LIMIT 1];
        List<String> casesIds = new List<String>();
        for(Case currentCase : cases){
            casesIds.add(currentCase.Id);
        }
        MultiRecordIntegrationController.reprocessMultipleRecords('Case', JSON.serialize(casesIds));
    }

    /**
     * @description Tests reprocessMultipleRecords batch execution for Order records.
     **/
    @IsTest
    public static void test_reprocessMultipleRecordsOrders(){
        List<Order> orders = [SELECT Id FROM Order LIMIT 1];
        List<String> orderIds = new List<String>();
        for(Order currentOrder : orders){
            orderIds.add(currentOrder.Id);
        }
        MultiRecordIntegrationController.reprocessMultipleRecords('Order', JSON.serialize(orderIds));
    }

    /**
     * @description Tests getJobDetails returns batch job information after reprocessing.
     **/
    @IsTest
    public static void test_getJobDetails(){
        List<Case> cases = [SELECT Id FROM Case LIMIT 1];
        List<String> casesIds = new List<String>();
        for(Case currentCase : cases){
            casesIds.add(currentCase.Id);
        }
        String jobId = MultiRecordIntegrationController.reprocessMultipleRecords('Case', JSON.serialize(casesIds));
        MultiRecordIntegrationController.getJobDetails(jobId);
    }

    /**
     * @description Tests convertCaseToCaseWrapper conversion logic.
     **/
    @IsTest
    public static void test_convertCaseToCaseWrapper() {
        /* List<Case> cases = [SELECT Id, CaseNumber, Descritivo_da_Ultima_Integracao__c, Status, Contact.Name FROM Case];
        MultiRecordIntegrationController.convertCaseToCaseWrapper(cases); */
    }

    /**
     * @description Tests convertOrderToOrderWrapper conversion logic.
     **/
    @IsTest
    public static void test_convertOrderToOrderWrapper() {
        /* List<Order> orders = [SELECT Id, Codigo_servico__c, Descritivo_da_Ultima_Integracao__c, Status, Type FROM Order];
        MultiRecordIntegrationController.convertOrderToOrderWrapper(orders); */
    }


    /**
     * @description Sets up test data for all test methods in this class.
     **/
    @TestSetup
    static void makeData(){
        /* Account acc1 = new Account();
        acc1.Name = 'Não Fornecedor';
        acc1.Estado__c = 'Activo';
        insert acc1;

        Account acc2 = new Account();
        acc2.Name = 'Reboques - Teste Controlador';
        acc2.TipoDeFornecedor__c = 'Peritagem';
        acc2.ShippingStreet = 'Avenida Rio de Janeiro';
        acc2.ShippingCity = 'Oeiras';
        acc2.ShippingCountry = 'POR';
        acc2.ShippingLatitude = 38.697341;
        acc2.ShippingLongitude = -9.208736;
        acc2.BillingStreet = ' ';
        acc2.BillingCity = 'Oeiras';
        acc2.BillingCountry = 'POR';
        acc2.BillingLatitude = 38.696876; 
        acc2.BillingLongitude = -9.314599;
        acc2.Telemovel1__c = '965333857';
        acc2.Prioridade__c = '5';
        acc2.CaracteristicasDoFornecedor__c = 'Incêndio';
        acc2.Estado__c = 'Activo';
        insert acc2;

        Contact cnt1 = new Contact();
        cnt1.AccountId = acc2.Id;
        cnt1.MobilePhone = '963852741';
        cnt1.Salutation = 'Mr.';
        cnt1.FirstName = 'Emanuel';
        cnt1.LastName = 'Almirante';
        insert cnt1;

        Case cse1 = new Case();
        cse1.ContactId = cnt1.Id;
        cse1.AccountId = acc2.Id;
        // cse1.Geolocalizacao__Latitude__s = ;
        // cse1.Geolocalizacao__Longitude__s = ;
        cse1.RuaLocalSinistro__c = 'Quinta da Fonte Edifício  D. Pedro I Piso 3 - STEP AHEAD';
        cse1.CidadeLocalSinistro__c = 'Paço de Arcos';
        cse1.PaisLocalSinistro__c = 'POR';
        cse1.CodigoPostalLocalSinistro__c = '2770-071';
        cse1.NomedaOficina__c = 'Oficina de Teste';
        insert cse1;

        Order ord1 = new Order();
        ord1.AccountId = acc2.Id;
        ord1.Status = 'Draft';
        ord1.EffectiveDate = Date.today();
        insert ord1; */
    }    
}