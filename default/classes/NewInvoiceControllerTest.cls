/**
 * @description Test class for NewInvoiceController.
 *              Covers: getOrderData, getServicesForOrder, createInvoice
 *              including Sede/Filial logic, IVA mapping, guild filtering and
 *              sequential invoice numbering.
 * @author      Daniel Flores
 * @group       Invoice
 * @last modified on  : 29-04-2026
 */
@isTest
private class NewInvoiceControllerTest {

    // ─── Test data setup ──────────────────────────────────────────────────────

    @testSetup
    static void setupTestData() {
        Id standardPbId = Test.getStandardPricebookId();

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Phone');
        insert testCase;

        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id   = prod.Id,
            UnitPrice    = 1,
            IsActive     = true
        );
        insert pbe;

        // Account Sede – postal Madrid (IVA 21)
        Account sede = new Account(
            Name              = 'Test Sede',
            SAPEntityCode__c  = 'SAPTEST',
            BillingPostalCode = '28001'
        );
        insert sede;

        // Account Filial – also Madrid, but has Pere__c filled and ParentId set
        Account filial = new Account(
            Name              = 'Test Filial',
            SAPEntityCode__c  = 'SAPFILIAL',
            BillingPostalCode = '28001',
            Pere__c           = 'SEDE',
            ParentId          = sede.Id
        );
        insert filial;

        // Account Canarias – IVA 7
        Account canarias = new Account(
            Name              = 'Test Canarias',
            SAPEntityCode__c  = 'SAPCAN',
            BillingPostalCode = '35001'
        );
        insert canarias;

        // Account Ceuta – IVA 4
        Account ceuta = new Account(
            Name              = 'Test Ceuta',
            SAPEntityCode__c  = 'SAPCE',
            BillingPostalCode = '51001'
        );
        insert ceuta;

        // Order for Sede
        Order orderSede = new Order(
            AccountId     = sede.Id,
            Status        = 'Open',
            EffectiveDate = Date.today(),
            Pricebook2Id  = standardPbId
        );
        insert orderSede;
        insert new OrderItem(OrderId = orderSede.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 1);

        // Order for Filial
        Order orderFilial = new Order(
            AccountId     = filial.Id,
            Status        = 'Open',
            EffectiveDate = Date.today(),
            Pricebook2Id  = standardPbId
        );
        insert orderFilial;
        insert new OrderItem(OrderId = orderFilial.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 1);

        // Order for Canarias (IVA 7)
        Order orderCanarias = new Order(
            AccountId     = canarias.Id,
            Status        = 'Open',
            EffectiveDate = Date.today(),
            Pricebook2Id  = standardPbId
        );
        insert orderCanarias;
        insert new OrderItem(OrderId = orderCanarias.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 1);

        // Order for Ceuta (IVA 4)
        Order orderCeuta = new Order(
            AccountId     = ceuta.Id,
            Status        = 'Open',
            EffectiveDate = Date.today(),
            Pricebook2Id  = standardPbId
        );
        insert orderCeuta;
        insert new OrderItem(OrderId = orderCeuta.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 1);

        // Services for Sede order – two guilds
        Service__c svc1 = new Service__c(
            Order__c              = orderSede.Id,
            Claim__c              = testCase.Id,
            StartDate__c          = Date.today(),
            Status__c             = 'Apertura',
            Type__c               = 'A1',
            TotalAmount__c        = 100,
            VATAmount__c          = 21,
            TotalAmountWithVAT__c = 121
        );
        Service__c svc2 = new Service__c(
            Order__c              = orderSede.Id,
            Claim__c              = testCase.Id,
            StartDate__c          = Date.today(),
            Status__c             = 'Apertura',
            Type__c               = 'A2',
            TotalAmount__c        = 200,
            VATAmount__c          = 42,
            TotalAmountWithVAT__c = 242
        );
        insert new List<Service__c>{ svc1, svc2 };

        // Services for Filial order
        Service__c svcFilial = new Service__c(
            Order__c              = orderFilial.Id,
            Claim__c              = testCase.Id,
            StartDate__c          = Date.today(),
            Status__c             = 'Apertura',
            Type__c               = 'A1',
            TotalAmount__c        = 150,
            VATAmount__c          = 31.5,
            TotalAmountWithVAT__c = 181.5
        );
        insert svcFilial;

        // Service for Canarias order
        Service__c svcCan = new Service__c(
            Order__c              = orderCanarias.Id,
            Claim__c              = testCase.Id,
            StartDate__c          = Date.today(),
            Status__c             = 'Apertura',
            Type__c               = 'A3',
            TotalAmount__c        = 50,
            VATAmount__c          = 3.5,
            TotalAmountWithVAT__c = 53.5
        );
        insert svcCan;

        // Service for Ceuta order
        Service__c svcCeuta = new Service__c(
            Order__c              = orderCeuta.Id,
            Claim__c              = testCase.Id,
            StartDate__c          = Date.today(),
            Status__c             = 'Apertura',
            Type__c               = 'A4',
            TotalAmount__c        = 80,
            VATAmount__c          = 3.2,
            TotalAmountWithVAT__c = 83.2
        );
        insert svcCeuta;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static Order getOrder(String accountName) {
        Account acc = [SELECT Id FROM Account WHERE Name = :accountName LIMIT 1];
        return [SELECT Id FROM Order WHERE AccountId = :acc.Id LIMIT 1];
    }

    private static List<Service__c> getServices(Id orderId) {
        return [SELECT Id FROM Service__c WHERE Order__c = :orderId];
    }

    private static Id getInvoiceRtId() {
        return Schema.SObjectType.Invoice__c
            .getRecordTypeInfosByDeveloperName().get('Invoice').getRecordTypeId();
    }

    // ─── getOrderData ─────────────────────────────────────────────────────────

    @isTest
    static void testGetOrderData_success() {
        Order ord = getOrder('Test Sede');
        Test.startTest();
        Map<String, String> result = NewInvoiceController.getOrderData(ord.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isNotNull(result.get('orderName'), 'orderName should be present');
        Assert.areEqual('Test Sede', result.get('accountName'), 'accountName should match');
    }

    @isTest
    static void testGetOrderData_nullId_throws() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            NewInvoiceController.getOrderData(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Should throw AuraHandledException for null orderId');
    }

    @isTest
    static void testGetOrderData_notFound_throws() {
        Boolean exceptionThrown = false;
        // Use a non-existent but valid-format Id
        Id fakeId = '8010Q00000AAAAxQAH';
        Test.startTest();
        try {
            NewInvoiceController.getOrderData(fakeId);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Should throw AuraHandledException when order not found');
    }

    // ─── getServicesForOrder ──────────────────────────────────────────────────

    @isTest
    static void testGetServicesForOrder_returnsAll_whenNoInvoices() {
        Order ord = getOrder('Test Sede');
        Test.startTest();
        List<NewInvoiceController.ServiceWrapper> result =
            NewInvoiceController.getServicesForOrder(ord.Id);
        Test.stopTest();

        Assert.areEqual(2, result.size(), 'Should return both services when no invoices exist');
    }

    @isTest
    static void testGetServicesForOrder_excludesAlreadyInvoicedGuild() {
        Order ord = getOrder('Test Sede');
        // Create an Invoice that already covers guild A1
        Invoice__c existingInv = new Invoice__c(
            RecordTypeId             = getInvoiceRtId(),
            Order__c                 = ord.Id,
            Guilds__c                = 'A1',
            Status__c                = 'Open',
            PreInvoiceNumber__c      = 'FT/SAPTEST/00001',
            PreInvoiceDate__c        = Datetime.now(),
            TotalAmountWithoutVAT__c = 100,
            VATAmount__c             = 21,
            TotalAmountWithVAT__c    = 121
        );
        insert existingInv;

        Test.startTest();
        List<NewInvoiceController.ServiceWrapper> result =
            NewInvoiceController.getServicesForOrder(ord.Id);
        Test.stopTest();

        Assert.areEqual(1, result.size(), 'Should exclude service for already invoiced guild A1');
        Assert.areEqual('A2', result[0].typeValue, 'Remaining service should be A2');
    }

    @isTest
    static void testGetServicesForOrder_wrapperFields() {
        Order ord = getOrder('Test Sede');
        Test.startTest();
        List<NewInvoiceController.ServiceWrapper> result =
            NewInvoiceController.getServicesForOrder(ord.Id);
        Test.stopTest();

        NewInvoiceController.ServiceWrapper w = result[0];
        Assert.isNotNull(w.id, 'id should be set');
        Assert.isNotNull(w.name, 'name should be set');
        Assert.isNotNull(w.typeValue, 'typeValue should be set');
        Assert.isNotNull(w.typeName, 'typeName should be set');
        Assert.isNotNull(w.totalAmount, 'totalAmount should be set');
    }

    // ─── createInvoice – direct account (Sede) ────────────────────────────────

    @isTest
    static void testCreateInvoice_directAccount_IVA21() {
        Order ord = getOrder('Test Sede');
        List<Id> svcIds = new List<Id>();
        for (Service__c s : getServices(ord.Id)) { svcIds.add(s.Id); }

        Test.startTest();
        Id invId = NewInvoiceController.createInvoice(ord.Id, svcIds, null);
        Test.stopTest();

        Assert.isNotNull(invId, 'Invoice Id should be returned');
        Invoice__c inv = [  
            SELECT PreInvoiceNumber__c, VATPercentage__c, Guilds__c,
                   TotalAmountWithoutVAT__c, VATAmount__c, TotalAmountWithVAT__c,
                   Status__c, Provider__c
            FROM Invoice__c WHERE Id = :invId
        ];

        Assert.isTrue(inv.PreInvoiceNumber__c.startsWith('FT/SAPTEST/'), 'Number prefix should be FT/SAPTEST/');
        Assert.areEqual('21', inv.VATPercentage__c, 'IVA should be 21 for Madrid postal code');
        Assert.areEqual('Open', inv.Status__c, 'Status should be Open');
        Assert.areEqual(300, inv.TotalAmountWithoutVAT__c, 'Base amount should sum services');
        Assert.areEqual(63, inv.VATAmount__c, 'VAT should sum services');
        Assert.areEqual(363, inv.TotalAmountWithVAT__c, 'Total with VAT should sum services');

        Account sede = [SELECT Id FROM Account WHERE Name = 'Test Sede'];
        Assert.areEqual(sede.Id, inv.Provider__c, 'Provider should be Sede account');
    }

    @isTest
    static void testCreateInvoice_sequentialNumbering() {
        Order ord = getOrder('Test Sede');
        List<Id> svc1Ids = new List<Id>{ getServices(ord.Id)[0].Id };
        List<Id> svc2Ids = new List<Id>{ getServices(ord.Id)[1].Id };

        Test.startTest();
        Id inv1Id = NewInvoiceController.createInvoice(ord.Id, svc1Ids, null);
        Id inv2Id = NewInvoiceController.createInvoice(ord.Id, svc2Ids, null);
        Test.stopTest();

        Invoice__c inv1 = [SELECT PreInvoiceNumber__c FROM Invoice__c WHERE Id = :inv1Id];
        Invoice__c inv2 = [SELECT PreInvoiceNumber__c FROM Invoice__c WHERE Id = :inv2Id];

        Assert.areEqual('FT/SAPTEST/00001', inv1.PreInvoiceNumber__c, 'First invoice should be 00001');
        Assert.areEqual('FT/SAPTEST/00002', inv2.PreInvoiceNumber__c, 'Second invoice should be 00002');
    }

    // ─── createInvoice – Filial uses Sede (ParentId) ─────────────────────────

    @isTest
    static void testCreateInvoice_filialUsesSedeAccount() {
        Order ord = getOrder('Test Filial');
        List<Id> svcIds = new List<Id>{ getServices(ord.Id)[0].Id };

        Test.startTest();
        Id invId = NewInvoiceController.createInvoice(ord.Id, svcIds, null);
        Test.stopTest();

        Invoice__c inv = [SELECT PreInvoiceNumber__c, Provider__c FROM Invoice__c WHERE Id = :invId];
        Account sede = [SELECT Id FROM Account WHERE Name = 'Test Sede'];

        Assert.isTrue(inv.PreInvoiceNumber__c.startsWith('FT/SAPTEST/'),
            'Number should use SEDE SAP code, not Filial');
        Assert.areEqual(sede.Id, inv.Provider__c, 'Provider should be Sede, not Filial');
    }

    // ─── createInvoice – IVA mapping ─────────────────────────────────────────

    @isTest
    static void testCreateInvoice_IVA7_mapsTo10() {
        Order ord = getOrder('Test Canarias');
        List<Id> svcIds = new List<Id>{ getServices(ord.Id)[0].Id };

        Test.startTest();
        Id invId = NewInvoiceController.createInvoice(ord.Id, svcIds, null);
        Test.stopTest();

        Invoice__c inv = [SELECT VATPercentage__c FROM Invoice__c WHERE Id = :invId];
        Assert.areEqual('10', inv.VATPercentage__c, 'IVA 7 (Canarias IGIC) should map to picklist value 10');
    }

    @isTest
    static void testCreateInvoice_IVA4() {
        Order ord = getOrder('Test Ceuta');
        List<Id> svcIds = new List<Id>{ getServices(ord.Id)[0].Id };

        Test.startTest();
        Id invId = NewInvoiceController.createInvoice(ord.Id, svcIds, null);
        Test.stopTest();

        Invoice__c inv = [SELECT VATPercentage__c FROM Invoice__c WHERE Id = :invId];
        Assert.areEqual('4', inv.VATPercentage__c, 'IVA 4 (Ceuta) should map to picklist value 4');
    }

    // ─── createInvoice – no SAP code falls back to UNKNOWN ───────────────────

    @isTest
    static void testCreateInvoice_noSapCode_usesUNKNOWN() {
        Id standardPbId = Test.getStandardPricebookId();
        Account noSap = new Account(Name = 'No SAP Account', BillingPostalCode = '28001');
        insert noSap;
        Order ord = new Order(
            AccountId     = noSap.Id,
            Status        = 'Open',
            EffectiveDate = Date.today(),
            Pricebook2Id  = standardPbId
        );
        insert ord;
        Product2 p = new Product2(Name = 'Prod NoSAP', IsActive = true);
        insert p;
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = standardPbId, Product2Id = p.Id, UnitPrice = 1, IsActive = true);
        insert pbe;
        insert new OrderItem(OrderId = ord.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 1);
        Case c2 = new Case(Subject = 'NoSAP Case', Status = 'New', Origin = 'Phone');
        insert c2;
        Service__c svc = new Service__c(
            Order__c              = ord.Id,
            Claim__c              = c2.Id,
            StartDate__c          = Date.today(),
            Status__c             = 'Apertura',
            Type__c               = 'A1',
            TotalAmount__c        = 10,
            VATAmount__c          = 2.1,
            TotalAmountWithVAT__c = 12.1
        );
        insert svc;

        Test.startTest();
        Id invId = NewInvoiceController.createInvoice(ord.Id, new List<Id>{ svc.Id }, null);
        Test.stopTest();

        Invoice__c inv = [SELECT PreInvoiceNumber__c FROM Invoice__c WHERE Id = :invId];
        Assert.isTrue(inv.PreInvoiceNumber__c.startsWith('FT/UNKNOWN/'),
            'Should fallback to UNKNOWN when no SAP code');
    }

    // ─── createInvoice – with caseId ─────────────────────────────────────────

    @isTest
    static void testCreateInvoice_withCaseId() {
        Order ord = getOrder('Test Sede');
        List<Id> svcIds = new List<Id>{ getServices(ord.Id)[0].Id };
        Case c = new Case(Subject = 'Test', Status = 'New', Origin = 'Phone');
        insert c;

        Test.startTest();
        Id invId = NewInvoiceController.createInvoice(ord.Id, svcIds, c.Id);
        Test.stopTest();

        Invoice__c inv = [SELECT Case__c FROM Invoice__c WHERE Id = :invId];
        Assert.areEqual(c.Id, inv.Case__c, 'Case should be linked to the created invoice');
    }
}