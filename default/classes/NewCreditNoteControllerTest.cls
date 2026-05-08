/**
 * @description Test class for NewCreditNoteController.
 *              Covers: getOrderData, getAvailableInvoices,
 *              getRectificationReasonOptions, createCreditNotes
 *              including Sede/Filial logic and sequential numbering.
 * @author      Daniel Flores
 * @group       Invoice
 * @last modified on  : 29-04-2026
 */
@isTest
private class NewCreditNoteControllerTest {

    // ─── Test data setup ──────────────────────────────────────────────────────

    @testSetup
    static void setupTestData() {
        Id standardPbId = Test.getStandardPricebookId();

        Product2 prod = new Product2(Name = 'Test Product CN', IsActive = true);
        insert prod;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id   = prod.Id,
            UnitPrice    = 1,
            IsActive     = true
        );
        insert pbe;

        // Account Sede
        Account sede = new Account(
            Name              = 'CN Sede',
            SAPEntityCode__c  = 'SAPTESTCN',
            BillingPostalCode = '28001'
        );
        insert sede;

        // Account Filial → Pere__c filled + ParentId = Sede
        Account filial = new Account(
            Name              = 'CN Filial',
            SAPEntityCode__c  = 'SAPFILIALLCN',
            BillingPostalCode = '28001',
            Pere__c           = 'SEDE',
            ParentId          = sede.Id
        );
        insert filial;

        // Orders
        Order orderSede = new Order(
            AccountId     = sede.Id,
            Status        = 'Open',
            EffectiveDate = Date.today(),
            Pricebook2Id  = standardPbId
        );
        insert orderSede;
        insert new OrderItem(OrderId = orderSede.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 1);

        Order orderFilial = new Order(
            AccountId     = filial.Id,
            Status        = 'Open',
            EffectiveDate = Date.today(),
            Pricebook2Id  = standardPbId
        );
        insert orderFilial;
        insert new OrderItem(OrderId = orderFilial.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 1);

        Id invoiceRtId = Schema.SObjectType.Invoice__c
            .getRecordTypeInfosByDeveloperName().get('Invoice').getRecordTypeId();

        // Three invoices for Sede order — two available, one will be credited later in test
        Invoice__c inv1 = new Invoice__c(
            RecordTypeId             = invoiceRtId,
            Order__c                 = orderSede.Id,
            Status__c                = 'Open',
            PreInvoiceNumber__c      = 'FT/SAPTESTCN/00001',
            PreInvoiceDate__c        = Datetime.now(),
            InvoiceDate__c           = Date.today(),
            TotalAmountWithoutVAT__c = 100,
            VATAmount__c             = 21,
            TotalAmountWithVAT__c    = 121
        );
        Invoice__c inv2 = new Invoice__c(
            RecordTypeId             = invoiceRtId,
            Order__c                 = orderSede.Id,
            Status__c                = 'Open',
            PreInvoiceNumber__c      = 'FT/SAPTESTCN/00002',
            PreInvoiceDate__c        = Datetime.now(),
            InvoiceDate__c           = Date.today(),
            TotalAmountWithoutVAT__c = 200,
            VATAmount__c             = 42,
            TotalAmountWithVAT__c    = 242
        );
        Invoice__c inv3 = new Invoice__c(
            RecordTypeId             = invoiceRtId,
            Order__c                 = orderSede.Id,
            Status__c                = 'Open',
            PreInvoiceNumber__c      = 'FT/SAPTESTCN/00003',
            PreInvoiceDate__c        = Datetime.now(),
            InvoiceDate__c           = Date.today(),
            TotalAmountWithoutVAT__c = 50,
            VATAmount__c             = 10.5,
            TotalAmountWithVAT__c    = 60.5
        );
        insert new List<Invoice__c>{ inv1, inv2, inv3 };

        // Invoice for Filial order
        Invoice__c invFilial = new Invoice__c(
            RecordTypeId             = invoiceRtId,
            Order__c                 = orderFilial.Id,
            Status__c                = 'Open',
            PreInvoiceNumber__c      = 'FT/SAPFILIALLCN/00001',
            PreInvoiceDate__c        = Datetime.now(),
            InvoiceDate__c           = Date.today(),
            TotalAmountWithoutVAT__c = 150,
            VATAmount__c             = 31.5,
            TotalAmountWithVAT__c    = 181.5
        );
        insert invFilial;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static Order getOrder(String accountName) {
        Account acc = [SELECT Id FROM Account WHERE Name = :accountName LIMIT 1];
        return [SELECT Id FROM Order WHERE AccountId = :acc.Id LIMIT 1];
    }

    private static List<Invoice__c> getInvoicesForOrder(Id orderId) {
        return [
            SELECT Id FROM Invoice__c
            WHERE Order__c = :orderId
              AND RecordType.DeveloperName = 'Invoice'
        ];
    }

    private static Id getCreditNoteRtId() {
        return Schema.SObjectType.Invoice__c
            .getRecordTypeInfosByDeveloperName().get('CreditNote').getRecordTypeId();
    }

    // ─── getOrderData ─────────────────────────────────────────────────────────

    @isTest
    static void testGetOrderData_success() {
        Order ord = getOrder('CN Sede');
        Test.startTest();
        Map<String, String> result = NewCreditNoteController.getOrderData(ord.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual('CN Sede', result.get('accountName'), 'accountName should match');
        Assert.isNotNull(result.get('orderName'), 'orderName should be present');
        Assert.isNotNull(result.get('accountId'), 'accountId should be present');
    }

    @isTest
    static void testGetOrderData_nullId_throws() {
        Boolean thrown = false;
        Test.startTest();
        try {
            NewCreditNoteController.getOrderData(null);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();
        Assert.isTrue(thrown, 'Should throw for null orderId');
    }

    @isTest
    static void testGetOrderData_notFound_throws() {
        Boolean thrown = false;
        Id fakeId = '8010Q00000AAAAxQAH';
        Test.startTest();
        try {
            NewCreditNoteController.getOrderData(fakeId);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();
        Assert.isTrue(thrown, 'Should throw when order not found');
    }

    // ─── getAvailableInvoices ─────────────────────────────────────────────────

    @isTest
    static void testGetAvailableInvoices_returnsAll_whenNoneCredited() {
        Order ord = getOrder('CN Sede');
        Test.startTest();
        List<NewCreditNoteController.InvoiceWrapper> result =
            NewCreditNoteController.getAvailableInvoices(ord.Id);
        Test.stopTest();

        Assert.areEqual(3, result.size(), 'All 3 invoices should be available when none are credited');
    }

    @isTest
    static void testGetAvailableInvoices_excludesCreditedInvoices() {
        Order ord = getOrder('CN Sede');
        List<Invoice__c> invoices = getInvoicesForOrder(ord.Id);

        // Create a credit note referencing the first invoice
        Invoice__c cn = new Invoice__c(
            RecordTypeId           = getCreditNoteRtId(),
            Order__c               = ord.Id,
            RelatedInvoice__c      = invoices[0].Id,
            RectificationReason__c = 'PriceError',
            CreditNoteNumber__c    = 'FT/SAPTESTCN/00001',
            CreditNoteDate__c      = Date.today(),
            Status__c              = 'Open'
        );
        insert cn;

        Test.startTest();
        List<NewCreditNoteController.InvoiceWrapper> result =
            NewCreditNoteController.getAvailableInvoices(ord.Id);
        Test.stopTest();

        Assert.areEqual(2, result.size(), 'Should return 2 invoices after 1 is already credited');
        for (NewCreditNoteController.InvoiceWrapper w : result) {
            Assert.areNotEqual(invoices[0].Id, w.id, 'Credited invoice should not appear in results');
        }
    }

    @isTest
    static void testGetAvailableInvoices_emptyOrder_returnsEmpty() {
        Id standardPbId = Test.getStandardPricebookId();
        Account acc = new Account(Name = 'Empty Order Account', BillingPostalCode = '28001');
        insert acc;
        Order ord = new Order(
            AccountId     = acc.Id,
            Status        = 'Open',
            EffectiveDate = Date.today(),
            Pricebook2Id  = standardPbId
        );
        insert ord;
        Product2 p = new Product2(Name = 'Prod Empty', IsActive = true);
        insert p;
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = standardPbId, Product2Id = p.Id, UnitPrice = 1, IsActive = true);
        insert pbe;
        insert new OrderItem(OrderId = ord.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 1);

        Test.startTest();
        List<NewCreditNoteController.InvoiceWrapper> result =
            NewCreditNoteController.getAvailableInvoices(ord.Id);
        Test.stopTest();

        Assert.areEqual(0, result.size(), 'Should return empty list when no invoices exist');
    }

    @isTest
    static void testGetAvailableInvoices_wrapperFields() {
        Order ord = getOrder('CN Sede');
        Test.startTest();
        List<NewCreditNoteController.InvoiceWrapper> result =
            NewCreditNoteController.getAvailableInvoices(ord.Id);
        Test.stopTest();

        NewCreditNoteController.InvoiceWrapper w = result[0];
        Assert.isNotNull(w.id, 'id should be set');
        Assert.isNotNull(w.name, 'name should be set');
        Assert.isNotNull(w.invoiceDate, 'invoiceDate should be set');
        Assert.isNotNull(w.totalAmountWithVAT, 'totalAmountWithVAT should be set');
        Assert.isFalse(w.selected, 'selected should default to false');
    }

    // ─── getRectificationReasonOptions ───────────────────────────────────────

    @isTest
    static void testGetRectificationReasonOptions_returnsOptions() {
        Test.startTest();
        List<Map<String, String>> options =
            NewCreditNoteController.getRectificationReasonOptions();
        Test.stopTest();

        Assert.isTrue(options.size() > 0, 'Should return at least one option');
        Map<String, String> first = options[0];
        Assert.isTrue(first.containsKey('label'), 'Option should have label');
        Assert.isTrue(first.containsKey('value'), 'Option should have value');
        Assert.areEqual('PriceError', first.get('value'), 'PriceError should be a valid option');
    }

    // ─── createCreditNotes – direct account (Sede) ───────────────────────────

    @isTest
    static void testCreateCreditNotes_directAccount() {
        Order ord = getOrder('CN Sede');
        List<Invoice__c> invoices = getInvoicesForOrder(ord.Id);
        List<Id> invoiceIds = new List<Id>{ invoices[0].Id };

        Test.startTest();
        List<Id> createdIds = NewCreditNoteController.createCreditNotes(
            ord.Id, 'PriceError', invoiceIds, null
        );
        Test.stopTest();

        Assert.areEqual(1, createdIds.size(), 'Should create 1 credit note');
        Invoice__c cn = [
            SELECT CreditNoteNumber__c, RelatedInvoice__c, RectificationReason__c,
                   Status__c, Provider__c, CreditNoteDate__c, RecordType.DeveloperName
            FROM Invoice__c WHERE Id = :createdIds[0]
        ];

        Assert.isTrue(cn.CreditNoteNumber__c.startsWith('FT/SAPTESTCN/'), 'Number should use Sede SAP code');
        Assert.areEqual('FT/SAPTESTCN/00001', cn.CreditNoteNumber__c, 'First credit note should be 00001');
        Assert.areEqual(invoices[0].Id, cn.RelatedInvoice__c, 'Should link to original invoice');
        Assert.areEqual('PriceError', cn.RectificationReason__c, 'Reason should match');
        Assert.areEqual('Open', cn.Status__c, 'Status should be Open');
        Assert.areEqual('CreditNote', cn.RecordType.DeveloperName, 'Record type should be CreditNote');

        Account sede = [SELECT Id FROM Account WHERE Name = 'CN Sede'];
        Assert.areEqual(sede.Id, cn.Provider__c, 'Provider should be Sede account');
    }

    @isTest
    static void testCreateCreditNotes_multipleInvoices_sequential() {
        Order ord = getOrder('CN Sede');
        List<Invoice__c> invoices = getInvoicesForOrder(ord.Id);
        List<Id> invoiceIds = new List<Id>{ invoices[0].Id, invoices[1].Id };

        Test.startTest();
        List<Id> createdIds = NewCreditNoteController.createCreditNotes(
            ord.Id, 'PriceError', invoiceIds, null
        );
        Test.stopTest();

        Assert.areEqual(2, createdIds.size(), 'Should create one credit note per invoice');

        List<Invoice__c> cns = [
            SELECT CreditNoteNumber__c
            FROM Invoice__c
            WHERE Id IN :createdIds
            ORDER BY CreditNoteNumber__c
        ];
        Assert.areEqual('FT/SAPTESTCN/00001', cns[0].CreditNoteNumber__c, 'First should be 00001');
        Assert.areEqual('FT/SAPTESTCN/00002', cns[1].CreditNoteNumber__c, 'Second should be 00002');
    }

    @isTest
    static void testCreateCreditNotes_counterIncrementsAcrossCalls() {
        Order ord = getOrder('CN Sede');
        List<Invoice__c> invoices = getInvoicesForOrder(ord.Id);

        Test.startTest();
        NewCreditNoteController.createCreditNotes(
            ord.Id, 'PriceError', new List<Id>{ invoices[0].Id }, null
        );
        List<Id> secondBatch = NewCreditNoteController.createCreditNotes(
            ord.Id, 'PriceError', new List<Id>{ invoices[1].Id }, null
        );
        Test.stopTest();

        Invoice__c secondCn = [SELECT CreditNoteNumber__c FROM Invoice__c WHERE Id = :secondBatch[0]];
        Assert.areEqual('FT/SAPTESTCN/00002', secondCn.CreditNoteNumber__c,
            'Second call should produce 00002 counter');
    }

    // ─── createCreditNotes – Filial uses Sede ────────────────────────────────

    @isTest
    static void testCreateCreditNotes_filialUsesSedeAccount() {
        Order ord = getOrder('CN Filial');
        List<Invoice__c> invoices = getInvoicesForOrder(ord.Id);

        Test.startTest();
        List<Id> createdIds = NewCreditNoteController.createCreditNotes(
            ord.Id, 'PriceError', new List<Id>{ invoices[0].Id }, null
        );
        Test.stopTest();

        Invoice__c cn = [SELECT CreditNoteNumber__c, Provider__c FROM Invoice__c WHERE Id = :createdIds[0]];
        Account sede = [SELECT Id FROM Account WHERE Name = 'CN Sede'];

        Assert.isTrue(cn.CreditNoteNumber__c.startsWith('FT/SAPTESTCN/'),
            'Number should use SEDE SAP code, not Filial');
        Assert.areEqual(sede.Id, cn.Provider__c, 'Provider should be Sede, not Filial');
    }

    // ─── createCreditNotes – no SAP code ─────────────────────────────────────

    @isTest
    static void testCreateCreditNotes_noSapCode_usesUNKNOWN() {
        Id standardPbId = Test.getStandardPricebookId();
        Account noSap = new Account(Name = 'No SAP CN Account', BillingPostalCode = '28001');
        insert noSap;
        Order ord = new Order(
            AccountId     = noSap.Id,
            Status        = 'Open',
            EffectiveDate = Date.today(),
            Pricebook2Id  = standardPbId
        );
        insert ord;
        Product2 p = new Product2(Name = 'Prod NoSAP CN', IsActive = true);
        insert p;
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = standardPbId, Product2Id = p.Id, UnitPrice = 1, IsActive = true);
        insert pbe;
        insert new OrderItem(OrderId = ord.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 1);

        Id invoiceRtId = Schema.SObjectType.Invoice__c
            .getRecordTypeInfosByDeveloperName().get('Invoice').getRecordTypeId();
        Invoice__c inv = new Invoice__c(
            RecordTypeId             = invoiceRtId,
            Order__c                 = ord.Id,
            Status__c                = 'Open',
            PreInvoiceNumber__c      = 'FT/UNKNOWN/00001',
            PreInvoiceDate__c        = Datetime.now(),
            InvoiceDate__c           = Date.today(),
            TotalAmountWithoutVAT__c = 100,
            VATAmount__c             = 21,
            TotalAmountWithVAT__c    = 121
        );
        insert inv;

        Test.startTest();
        List<Id> createdIds = NewCreditNoteController.createCreditNotes(
            ord.Id, 'PriceError', new List<Id>{ inv.Id }, null
        );
        Test.stopTest();

        Invoice__c cn = [SELECT CreditNoteNumber__c FROM Invoice__c WHERE Id = :createdIds[0]];
        Assert.isTrue(cn.CreditNoteNumber__c.startsWith('FT/UNKNOWN/'),
            'Should fallback to UNKNOWN when no SAP code');
    }

    // ─── createCreditNotes – with caseId ─────────────────────────────────────

    @isTest
    static void testCreateCreditNotes_withCaseId() {
        Order ord = getOrder('CN Sede');
        List<Invoice__c> invoices = getInvoicesForOrder(ord.Id);
        Case c = new Case(Subject = 'Test CN Case', Status = 'New', Origin = 'Phone');
        insert c;

        Test.startTest();
        List<Id> createdIds = NewCreditNoteController.createCreditNotes(
            ord.Id, 'PriceError', new List<Id>{ invoices[0].Id }, c.Id
        );
        Test.stopTest();

        Invoice__c cn = [SELECT Case__c FROM Invoice__c WHERE Id = :createdIds[0]];
        Assert.areEqual(c.Id, cn.Case__c, 'Case should be linked to the created credit note');
    }

    // ─── createCreditNotes – invalid orderId throws ───────────────────────────

    @isTest
    static void testCreateCreditNotes_orderNotFound_throws() {
        Boolean thrown = false;
        Id fakeId = '8010Q00000AAAAxQAH';
        Test.startTest();
        try {
            NewCreditNoteController.createCreditNotes(
                fakeId, 'PriceError', new List<Id>(), null
            );
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();
        Assert.isTrue(thrown, 'Should throw AuraHandledException when order not found');
    }
}