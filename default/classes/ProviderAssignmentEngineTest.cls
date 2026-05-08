/**
 * @description       :
 * @author            : Afonso Duque
 * @group             :
 * @last modified on  : 30-04-2026
 * @last modified by  : Daniel Flores
**/
@isTest
public with sharing class ProviderAssignmentEngineTest {

    @TestSetup
    static void makeData(){

        List<Account> accountsToInsert = new List<Account>();
        Account acc = new Account(
            Name = 'Provider 1',
            DailyCapacity__c = 10,
            MaxOpenJobs__c = 20,
            DailyAssignedJobs__c = 0,
            AssignedOpenJobs__c = 1,
            Ranking__c = 100,
            ShippingStreet = '123 Main St',
            ShippingCity = 'Lisbon',
            ShippingState = 'Lisbon',
            ShippingPostalCode = '1000',
            ShippingCountry = 'Portugal',
            WorkPostalCodes__c = '1000'
        );
        accountsToInsert.add(acc);

        Account acc1 = new Account(
            Name = 'Provider 2',
            DailyCapacity__c = 10,
            MaxOpenJobs__c = 20,
            DailyAssignedJobs__c = 0,
            AssignedOpenJobs__c = 1,
            Ranking__c = 1
        );
        accountsToInsert.add(acc1);

        Account acc2 = new Account(
            Name = 'Provider 3',
            Ranking__c = 0
        );
        accountsToInsert.add(acc2);
        insert accountsToInsert;

        Contact c = new Contact(
            LastName='Test Contact',
            AccountId=acc.Id
        );
        insert c;

        AccountInformation__c accInfoPhone = new AccountInformation__c(
            Account__c = acc.Id,
            Type__c = 'Phone',
            Value__c = '911111111'
        );
        insert accInfoPhone;

        AccountInformation__c accInfoEmail = new AccountInformation__c(
            Account__c = acc.Id,
            Type__c = 'Email',
            Value__c = 'test@example.com'
        );
        insert accInfoEmail;

        Case caseRecord = new Case(
            Subject = 'Test Case',
            Status = 'Opening',
            Origin = 'Phone',
            AccountId = acc.Id,
            ContactId = c.Id
        );
        insert caseRecord;

        Order encargo = new Order(
            Name = 'Test Encargo',
            AccountId = acc.Id,
            CaseNumber__c = caseRecord.Id,
            EffectiveDate = Date.today(),
            Status = 'Open',
            BillingPostalCode = '1000'
        );
        insert encargo;

        Order encargoNoPostal = new Order(
            Name = 'Test Encargo NO Postal',
            AccountId = acc.Id,
            CaseNumber__c = caseRecord.Id,
            EffectiveDate = Date.today(),
            Status = 'Open'
        );
        insert encargoNoPostal;

        Order encargoNoProviders = new Order(
            Name = 'Test Encargo NO Providers',
            AccountId = acc.Id,
            CaseNumber__c = caseRecord.Id,
            EffectiveDate = Date.today(),
            Status = 'Open',
            BillingPostalCode = '666'
        );
        insert encargoNoProviders;
    }

    @isTest
    static void testGetProviders(){
        Account provider = [SELECT Id FROM Account WHERE Name = 'Provider 1' LIMIT 1];
        ProviderAssignmentEngine.AssignInfo assignInfo = new ProviderAssignmentEngine.AssignInfo();
        assignInfo.reason = 'test reason';
        assignInfo.description = 'test description';

        Map<String, ProviderAssignmentEngine.AssignInfo> providersInfo = new Map<String, ProviderAssignmentEngine.AssignInfo>{
            provider.Id => assignInfo
        };

        Test.startTest();
        List<ProviderAssignmentEngine.Provider> result = ProviderAssignmentEngine.getProviders(providersInfo);
        System.assertEquals(true, result.size() > 0);
        System.assertEquals(provider.Id, result[0].Id);
        Test.stopTest();
    }

    @isTest
    static void testGetAssignmentsNoProviders(){
        Order encargo = [SELECT Id FROM Order WHERE BillingPostalCode = '666' LIMIT 1];

        Test.startTest();
        ProviderAssignmentEngine.AssignmentResult result = ProviderAssignmentEngine.getAssignments(encargo.Id, null, false);
        System.assertEquals(false, result.success);
        Test.stopTest();
    }

    @isTest
    static void testGetAssignmentsAutomatic(){
        Order encargo = [SELECT Id FROM Order WHERE BillingPostalCode = '1000' LIMIT 1];
        Account provider = [SELECT Id FROM Account WHERE Name = 'Provider 1' LIMIT 1];

        Test.startTest();
        ProviderAssignmentEngine.AssignmentResult result = ProviderAssignmentEngine.getAssignments(encargo.Id, null, false);
        System.assertEquals(true, result.success);
        System.assertEquals(provider.Id, result.providerId);
        Test.stopTest();
    }

    @isTest
    static void testGetAssignmentsManual(){
        Order encargo = [SELECT Id FROM Order WHERE BillingPostalCode = '1000' LIMIT 1];

        Test.startTest();
        ProviderAssignmentEngine.AssignmentResult result = ProviderAssignmentEngine.getAssignments(encargo.Id, null, true);
        System.assertEquals(true, result.success);
        System.assertEquals(true, !result.manualResults.isEmpty());
        System.assertEquals(1, result.manualResults.size());
        Test.stopTest();
    }

    @isTest
    static void testGetAssignmentsAutomaticNoPostal(){
        Order encargo = [SELECT Id FROM Order WHERE BillingPostalCode = null LIMIT 1];

        Test.startTest();
        ProviderAssignmentEngine.AssignmentResult result = ProviderAssignmentEngine.getAssignments(encargo.Id, null, false);
        System.assertEquals(true, result.success);
        Test.stopTest();
    }

    @isTest
    static void testGetAssignmentsManualNoPostal(){
        Order encargo = [SELECT Id FROM Order WHERE BillingPostalCode = null LIMIT 1];

        Test.startTest();
        ProviderAssignmentEngine.AssignmentResult result = ProviderAssignmentEngine.getAssignments(encargo.Id, null, true);
        System.assertEquals(true, result.success);
        System.assertEquals(true, !result.manualResults.isEmpty());
        System.assertEquals(3, result.manualResults.size());
        Test.stopTest();
    }

    @isTest
    static void TestAssignEncargoWithConfig(){
        Order encargo = [SELECT Id FROM Order WHERE BillingPostalCode = '1000' LIMIT 1];

        Test.startTest();
        ProviderAssignmentEngine.AssignmentResult result = ProviderAssignmentEngine.assignEncargoWithConfig(encargo.Id, '{}');
        System.assertEquals(true, result.success);
        Test.stopTest();
    }

    @isTest
    static void TestGetAllDependentProviderGuilds(){
        Test.startTest();
        ProviderAssignmentEngine.getAllDependentProviderGuilds();
        Test.stopTest();
    }

    @isTest
    static void TestCreateOrderFalse(){

        Order encargo = [SELECT Id, AccountId FROM Order WHERE BillingPostalCode = '1000' LIMIT 1];
        Case caseRecord = [SELECT Id, CaseNumber FROM Case LIMIT 1];

        ProviderAssignmentEngine.OrderInfo orderInfo = new ProviderAssignmentEngine.OrderInfo();
        orderInfo.id = encargo.Id;
        orderInfo.type = 'Claim';
        orderInfo.providerType = 'MU';
        orderInfo.guild = new List<String>{'B3'};
        orderInfo.urgent = true;
        orderInfo.caseId = caseRecord.Id;
        orderInfo.providerId = encargo.AccountId;

        Test.startTest();
        ProviderAssignmentEngine.createOrder(JSON.serialize(orderInfo), false);
        Test.stopTest();
    }

    @isTest
    static void TestCreateOrderTrue(){

        Order encargo = [SELECT Id, AccountId FROM Order WHERE BillingPostalCode = '1000' LIMIT 1];
        Case caseRecord = [SELECT Id, CaseNumber FROM Case LIMIT 1];

        ProviderAssignmentEngine.OrderInfo orderInfo = new ProviderAssignmentEngine.OrderInfo();
        orderInfo.id = encargo.Id;
        orderInfo.type = 'Claim';
        orderInfo.providerType = 'Multi-trade';
        orderInfo.guild = new List<String>{'ABOGADO'};
        orderInfo.urgent = true;
        orderInfo.caseId = caseRecord.Id;
        orderInfo.providerId = encargo.AccountId;

        Test.startTest();
        ProviderAssignmentEngine.createOrder(JSON.serialize(orderInfo), true);
        Test.stopTest();
    }

    @isTest
    static void TestCreateAlgorithmOutcome(){

        Order encargo = [SELECT Id, AccountId FROM Order WHERE BillingPostalCode = '1000' LIMIT 1];

        Test.startTest();
        ProviderAssignmentEngine.createAlgorithmOutcome('teste', 'Automatic', encargo.Id);
        Test.stopTest();
    }

    @isTest
    static void TestAssignEncargo(){

        Order encargo = [SELECT Id, AccountId FROM Order WHERE BillingPostalCode = '1000' LIMIT 1];

        Test.startTest();
        ProviderAssignmentEngine.assignEncargo(encargo.Id, null);
        Test.stopTest();
    }

    @isTest
    static void TestAssignProvidersWithMode(){

        Order encargo = [SELECT Id, AccountId FROM Order WHERE BillingPostalCode = '1000' LIMIT 1];

        List<ProviderAssignmentEngine.FlowRequestWithMode> requests = new List<ProviderAssignmentEngine.FlowRequestWithMode>();
        ProviderAssignmentEngine.FlowRequestWithMode request = new ProviderAssignmentEngine.FlowRequestWithMode();
        request.isManual = true;
        request.encargoId = encargo.Id;
        requests.add(request);

        Test.startTest();
        ProviderAssignmentEngine.AssignProvidersWithMode(requests);
        Test.stopTest();
    }

    @isTest
    static void TestAssignmentConfigPut(){

        ProviderAssignmentEngine.AssignmentConfig config = new ProviderAssignmentEngine.AssignmentConfig();
        Decimal originalValue = config.defaultOverPendingFactor;
        Decimal newValue = 2.5;

        Test.startTest();
        config.put('defaultOverPendingFactor', newValue);
        Test.stopTest();

        System.assertEquals(newValue, config.defaultOverPendingFactor, 'put should update defaultOverPendingFactor');
    }

    @isTest
    static void TestBuildErrorResult(){

        Test.startTest();
        ProviderAssignmentEngine.AssignmentResult result = ProviderAssignmentEngine.assignEncargo(null, null, true);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Error result should have success = false');
    }

    @isTest
    static void TestTryLoadSupplierGuildTypesWithLookup(){

        Order encargo = [SELECT Id, AccountId FROM Order WHERE BillingPostalCode = '1000' LIMIT 1];

        SupplierGuild__c supplierGuild = new SupplierGuild__c(
            Type__c = 'FONTANERO',
            StartDate__c = Date.today().addDays(-1),
            EndDate__c = Date.today().addDays(1),
            Account__c = encargo.AccountId
        );
        insert supplierGuild;

        Test.startTest();
        Boolean result = ProviderAssignmentEngine.tryLoadSupplierGuildTypesWithLookup(new Set<Id>{encargo.AccountId}, new ProviderAssignmentEngine.AssignmentConfig(), 'Account__c', new Set<String>{'FONTANERO'});
        Test.stopTest();

        System.assertEquals(true, result, 'Expected to successfully load supplier guild types with lookup');
    }

    @isTest
    static void TestIsTruthy(){

        Test.startTest();
        Boolean result = ProviderAssignmentEngine.isTruthy('YES');
        Test.stopTest();

        System.assertEquals(true, result, 'Expected to successfully load supplier guild types with lookup');
    }

    @isTest
    static void testIsWithinOnCallCalendar() {
        // Test with a single interval covering the current month (February)
        Date referenceDate = Date.newInstance(2026, 2, 9); // Current date
        // Spanish months: "Enero" (1), "Febrero" (2), ...
        System.assertEquals(true, ProviderAssignmentEngine.isWithinOnCallCalendar('Enero-Marzo', referenceDate), 'Should be within interval Enero-Marzo');
        System.assertEquals(true, ProviderAssignmentEngine.isWithinOnCallCalendar('Febrero-Febrero', referenceDate), 'Should be within interval Febrero-Febrero');
        System.assertEquals(false, ProviderAssignmentEngine.isWithinOnCallCalendar('Marzo-Abril', referenceDate), 'Should not be within interval Marzo-Abril');

        // Test with multiple intervals, one matching
        String multi = 'Enero-Enero; Febrero-Marzo';
        System.assertEquals(true, ProviderAssignmentEngine.isWithinOnCallCalendar(multi, referenceDate), 'Should match one of multiple intervals');

        // Test with interval that wraps year end
        System.assertEquals(true, ProviderAssignmentEngine.isWithinOnCallCalendar('Diciembre-Febrero', referenceDate), 'Should match wrapping interval Diciembre-Febrero');
        System.assertEquals(false, ProviderAssignmentEngine.isWithinOnCallCalendar('Marzo-Noviembre', referenceDate), 'Should not match wrapping interval Marzo-Noviembre');

        // Test with invalid/blank input
        System.assertEquals(false, ProviderAssignmentEngine.isWithinOnCallCalendar('', referenceDate), 'Blank calendar should return false');
        System.assertEquals(false, ProviderAssignmentEngine.isWithinOnCallCalendar(null, referenceDate), 'Null calendar should return false');
        System.assertEquals(false, ProviderAssignmentEngine.isWithinOnCallCalendar('Enero-Marzo', null), 'Null date should return false');
        System.assertEquals(false, ProviderAssignmentEngine.isWithinOnCallCalendar('Invalid-Text', referenceDate), 'Invalid month should return false');
    }

    @isTest
    static void testPreferenceRules() {
        Order encargo = [SELECT Id, AccountId/* , SubCausa__c */ FROM Order WHERE BillingPostalCode = '1000' LIMIT 1];
        Account provider = [SELECT Id FROM Account WHERE Id = :encargo.AccountId LIMIT 1];

        Test.startTest();
        ProviderAssignmentEngine.PreferenceRule rule = new ProviderAssignmentEngine.PreferenceRule();
        rule.matches(encargo, provider, new ProviderAssignmentEngine.AssignmentConfig());
        rule.trade = 'A2';
        rule.matches(encargo, provider, new ProviderAssignmentEngine.AssignmentConfig());
        rule.providerId = encargo.Id;
        rule.matches(encargo, provider, new ProviderAssignmentEngine.AssignmentConfig());
        Test.stopTest();
    }

    @isTest
    static void testCalendarWindow() {
        Order encargo = [SELECT Id, AccountId/* , SubCausa__c */ FROM Order WHERE BillingPostalCode = '1000' LIMIT 1];

        Test.startTest();
        ProviderAssignmentEngine.CalendarWindow calendarWindow = new ProviderAssignmentEngine.CalendarWindow();
        calendarWindow.isActiveFor(encargo.AccountId, null);
        calendarWindow.providerId = encargo.Id;
        calendarWindow.isActiveFor(encargo.AccountId, null);
        Test.stopTest();
    }

    @isTest
    static void testGetDate() {
        Order encargo = [SELECT Id, AccountId, /* SubCausa__c, */ Type, EffectiveDate FROM Order WHERE BillingPostalCode = '1000' LIMIT 1];

        Test.startTest();
        Date data = ProviderAssignmentEngine.getDate(encargo, 'EffectiveDate');
        Date data2 = ProviderAssignmentEngine.getDate(encargo, 'Type');
        Date data3 = ProviderAssignmentEngine.getDate(null, 'Type');
        Test.stopTest();
    }

    @isTest
    static void testEvaluateProvider() {
        Order encargo = [SELECT Id, AccountId, /* SubCausa__c, */ Type, EffectiveDate, Urgent__c, Guild__c, BillingPostalCode FROM Order WHERE BillingPostalCode = '1000' LIMIT 1];
        Account provider = [SELECT Id, Name, /* CalendarAvailability__c, */ RegistrationDate__c, TerminationDate__c,
                                    /* Situation__c, */ WorkPostalCodes__c, DailyCapacity__c, Guild__c,
                                    MaxOpenJobs__c, DailyAssignedJobs__c, AssignedOpenJobs__c,
                                    OverloadFactor__c, OverpendingFactor__c, CapacityPriority__c,
                                    Ranking__c/* , OnCallCalendar__c *//* , EmergencyService__c */
                                    FROM Account
                                    WHERE Id = :encargo.AccountId
                                    LIMIT 1];

        Test.startTest();
        ProviderAssignmentEngine.ProviderSnapshot snap = ProviderAssignmentEngine.evaluateProvider(encargo, provider, new ProviderAssignmentEngine.AssignmentConfig());

        ProviderAssignmentEngine.AssignmentConfig config = new ProviderAssignmentEngine.AssignmentConfig();
        // matchesCalendarAvailability
       /*  provider.CalendarAvailability__c = 'MON-SUN'; */
        // matchesSituation
        /* provider.Situation__c = 'Sí'; */
        provider.RegistrationDate__c = Date.today().addDays(1);
        provider.TerminationDate__c = Date.today().addDays(1);
        // matchesUrgency
        encargo.Urgent__c = true;
        /* provider.OnCallCalendar__c = String.valueOf('Enero-Junio'); */
       /*  provider.EmergencyService__c = String.valueOf(System.today()); */
        // matchesTypeAndGuild
        encargo.Guild__c = 'ABOGADO;FONTANERO';
        provider.Guild__c = 'ABOGADO;FONTANERO';
        config.supplierGuildQuerySucceeded = true;
        // matchesPostalCode
        provider.WorkPostalCodes__c = '1000;2000';
        // matchesPreferencesAndVetos
        ProviderAssignmentEngine.PreferenceRule rule = new ProviderAssignmentEngine.PreferenceRule();
        rule.type = ProviderAssignmentEngine.PreferenceRuleType.PREFERENCE;
        config.preferenceRules = new List<ProviderAssignmentEngine.PreferenceRule>{
            rule
        };
        // MatchesEqipment
        config.providerEquipmentBrands = new Map<Id, Set<String>>{
            provider.Id => new Set<String>{'ABOGADO', 'FONTANERO'}
        };
        config.encargoEquipmentField = 'Guild__c';
        config.encargoBrandField = 'Type';
        encargo.Guild__c = 'ABOGADO';
        ProviderAssignmentEngine.evaluateProvider(encargo, provider, config);

        /* provider.CalendarAvailability__c = 'SUN-MON'; */
        ProviderAssignmentEngine.evaluateProvider(encargo, provider, config);

        //Errors
        /* provider.CalendarAvailability__c = null; */
        provider.RegistrationDate__c = Date.today().addDays(-1);
        ProviderAssignmentEngine.evaluateProvider(encargo, provider, config);

        provider.RegistrationDate__c = Date.today().addDays(1);
        /* provider.OnCallCalendar__c = String.valueOf('Enero'); */
        ProviderAssignmentEngine.evaluateProvider(encargo, provider, config);

        provider.Guild__c = '';
        /* provider.OnCallCalendar__c = String.valueOf('Enero-Junio'); */
        ProviderAssignmentEngine.evaluateProvider(encargo, provider, config);

        provider.Guild__c = 'ABOGADO;FONTANERO';
        provider.WorkPostalCodes__c = '2000';
        ProviderAssignmentEngine.evaluateProvider(encargo, provider, config);

        provider.WorkPostalCodes__c = '1000;2000';
        rule.type = ProviderAssignmentEngine.PreferenceRuleType.VETO;
        config.preferenceRules = new List<ProviderAssignmentEngine.PreferenceRule>{
            rule
        };
        ProviderAssignmentEngine.evaluateProvider(encargo, provider, config);

        rule.type = ProviderAssignmentEngine.PreferenceRuleType.PREFERENCE;
        config.preferenceRules = new List<ProviderAssignmentEngine.PreferenceRule>{
            rule
        };
        encargo.Guild__c = 'ABOGADO;FONTANERO';
        ProviderAssignmentEngine.evaluateProvider(encargo, provider, config);

        encargo.Guild__c = 'ABOGADO';
        provider.OverloadFactor__c = '1';
        provider.DailyAssignedJobs__c = -1;
        provider.AssignedOpenJobs__c = 100;
        ProviderAssignmentEngine.evaluateProvider(encargo, provider, config);

        //ProviderAssignmentEngine.matchesCoverageLimit(encargo, provider, config, snap);
        Test.stopTest();
    }

    @IsTest
    static void selectBest_returnsHighestScoreEligible_only() {
        Account a1 = new Account(Name = 'Provider A');
        Account a2 = new Account(Name = 'Provider B');
        insert new List<Account>{ a1, a2 };

        ProviderAssignmentEngine.ProviderSnapshot s1 = new ProviderAssignmentEngine.ProviderSnapshot(a1);
        s1.eligible = true;
        s1.score = 10;

        ProviderAssignmentEngine.ProviderSnapshot s2 = new ProviderAssignmentEngine.ProviderSnapshot(a2);
        s2.eligible = false;
        s2.score = 999;

        ProviderAssignmentEngine.ProviderSnapshot best = ProviderAssignmentEngine.selectBest(
            new List<ProviderAssignmentEngine.ProviderSnapshot>{ s1, s2 }
        );

        System.assertNotEquals(null, best, 'Expected an eligible best provider');
        System.assertEquals(a1.Id, best.providerId, 'Ineligible providers must never be selected');
    }

    @IsTest
    static void selectBest_returnsNullWhenNoneEligible() {
        Account a1 = new Account(Name = 'Provider A');
        insert a1;

        ProviderAssignmentEngine.ProviderSnapshot s1 = new ProviderAssignmentEngine.ProviderSnapshot(a1);
        s1.eligible = false;
        s1.score = 10;

        ProviderAssignmentEngine.ProviderSnapshot best = ProviderAssignmentEngine.selectBest(
            new List<ProviderAssignmentEngine.ProviderSnapshot>{ s1 }
        );

        System.assertEquals(null, best, 'Expected null when no provider is eligible');
    }

    @IsTest
    static void selectBest_tieBreak_isDeterministic() {
        Account a1 = new Account(Name = 'Provider A');
        Account a2 = new Account(Name = 'Provider B');
        insert new List<Account>{ a1, a2 };

        ProviderAssignmentEngine.ProviderSnapshot s1 = new ProviderAssignmentEngine.ProviderSnapshot(a1);
        s1.eligible = true;
        s1.score = 10;

        ProviderAssignmentEngine.ProviderSnapshot s2 = new ProviderAssignmentEngine.ProviderSnapshot(a2);
        s2.eligible = true;
        s2.score = 10;

        ProviderAssignmentEngine.ProviderSnapshot best1 = ProviderAssignmentEngine.selectBest(
            new List<ProviderAssignmentEngine.ProviderSnapshot>{ s1, s2 }
        );
        ProviderAssignmentEngine.ProviderSnapshot best2 = ProviderAssignmentEngine.selectBest(
            new List<ProviderAssignmentEngine.ProviderSnapshot>{ s2, s1 }
        );

        System.assertNotEquals(null, best1);
        System.assertNotEquals(null, best2);
        System.assertEquals(best1.providerId, best2.providerId, 'Tie-break should not depend on list order');
    }
}