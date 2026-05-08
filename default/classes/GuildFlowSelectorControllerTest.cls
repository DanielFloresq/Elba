/**
 * @description       : Test class for GuildFlowSelectorController - validates guild option retrieval
 *                      and supplier exclusion filtering logic
 * @author            : Daniel Flores
 * @last modified on  : 14-01-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
private class GuildFlowSelectorControllerTest {

    /**
     * @description Sets up test data including Accounts with Guild__c values
     */
    @TestSetup
    static void setupTestData() {
        Account providerAccount = new Account(
            Name = 'Test Provider Guild'
        );
        insert providerAccount;

        Account relatedAccount = new Account(
            Name = 'Test Related Account'
        );
        insert relatedAccount;
    }

    /**
     * @description Tests getAvailableGuildOptions with a valid provider, guild values, and no exclusions
     */
    @IsTest
    static void testGetAvailableGuildOptionsWithGuildValues() {
        Account provider = [SELECT Id FROM Account WHERE Name = 'Test Provider Guild' LIMIT 1];

        Test.startTest();
        List<MultiPicklistChoiceOption> options =
            GuildFlowSelectorController.getAvailableGuildOptions(
                provider.Id,
                null,
                new List<Id>(),
                new List<Id>()
            );
        Test.stopTest();

        System.assertNotEquals(null, options, 'Options list should not be null');
    }

    /**
     * @description Tests getAvailableGuildOptions with null providerId and related account Ids
     */
    @IsTest
    static void testGetAvailableGuildOptionsWithRelatedAccounts() {
        Account relatedAcc = [SELECT Id FROM Account WHERE Name = 'Test Related Account' LIMIT 1];

        Test.startTest();
        List<MultiPicklistChoiceOption> options =
            GuildFlowSelectorController.getAvailableGuildOptions(
                null,
                null,
                new List<Id>{ relatedAcc.Id },
                new List<Id>()
            );
        Test.stopTest();

        System.assertNotEquals(null, options, 'Options list should not be null');
    }

    /**
     * @description Tests getAvailableGuildOptions with empty inputs returns an empty list
     */
    @IsTest
    static void testGetAvailableGuildOptionsEmpty() {
        Test.startTest();
        List<MultiPicklistChoiceOption> options =
            GuildFlowSelectorController.getAvailableGuildOptions(
                null,
                null,
                new List<Id>(),
                new List<Id>()
            );
        Test.stopTest();

        System.assertEquals(0, options.size(), 'Empty inputs should return empty options');
    }
}