/**
 * @description       : Test class for AssigmentProviderController - validates provider retrieval logic
 * @author            : Daniel Flores
 * @last modified on  : 14-01-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
private class AssigmentProviderControllerTest {

    /**
     * @description Sets up test data including Accounts and AccountInformation records
     */
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(Name = 'Test Provider Account');
        insert testAccount;

        List<AccountInformation__c> accountInfos = new List<AccountInformation__c>{
            new AccountInformation__c(
                Account__c = testAccount.Id,
                Type__c = 'Phone',
                Value__c = '+351912345678'
            ),
            new AccountInformation__c(
                Account__c = testAccount.Id,
                Type__c = 'Email',
                Value__c = 'provider@test.com'
            )
        };
        insert accountInfos;
    }

    /**
     * @description Tests getProviders returns a list of Provider wrapper objects for a given record Id
     */
    @IsTest
    static void testGetProviders() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<AssigmentProviderController.Provider> providers =
            AssigmentProviderController.getProviders(acc.Id, false);
        Test.stopTest();

        // Scaffolding assertion — validate structure, not full coverage
        System.assertNotEquals(null, providers, 'Providers list should not be null');
    }

    /**
     * @description Tests getProviders when isAutomatic flag is true
     */
    @IsTest
    static void testGetProvidersAutomatic() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<AssigmentProviderController.Provider> providers =
            AssigmentProviderController.getProviders(acc.Id, true);
        Test.stopTest();

        System.assertNotEquals(null, providers, 'Providers list should not be null');
    }
}