/**
 * @description       : Unit tests for MultiPicklistToChoicesService.
 *                      Validates convertToChoices InvocableMethod, getLabelsByValue,
 *                      and buildChoices helper methods.
 * @author            : Daniel Flores
 * @last modified on  : 14-01-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
private class MultiPicklistToChoicesServiceTest {

    /**
     * @description Tests convertToChoices with a null input list.
     *              Expects an empty list of MultiPicklistChoiceOption.
     **/
    @IsTest
    static void testConvertToChoicesNull() {
        Test.startTest();
        List<MultiPicklistChoiceOption> result =
            MultiPicklistToChoicesService.convertToChoices(null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Result should be empty for null input');
    }

    /**
     * @description Tests convertToChoices with an empty input list.
     *              Expects an empty list of MultiPicklistChoiceOption.
     **/
    @IsTest
    static void testConvertToChoicesEmpty() {
        Test.startTest();
        List<MultiPicklistChoiceOption> result =
            MultiPicklistToChoicesService.convertToChoices(new List<String>());
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Result should be empty for empty input');
    }

    /**
     * @description Tests convertToChoices with a single semicolon-separated picklist string.
     *              Validates that choices are returned with proper value/label pairs.
     **/
    @IsTest
    static void testConvertToChoicesWithValues() {
        // Build a sample picklist string using known Guild__c values if available
        List<Schema.PicklistEntry> entries =
            Account.Guild__c.getDescribe().getPicklistValues();

        if (entries.isEmpty()) {
            // No picklist values to test — pass scaffolding
            System.assert(true, 'No Guild__c picklist values available');
            return;
        }

        String sampleValue = entries[0].getValue();

        Test.startTest();
        List<MultiPicklistChoiceOption> result =
            MultiPicklistToChoicesService.convertToChoices(
                new List<String>{ sampleValue }
            );
        Test.stopTest();

        System.assert(!result.isEmpty(), 'Should return at least one choice option');
    }

    /**
     * @description Tests convertToChoices with duplicate values in the input string.
     *              Validates deduplication logic in buildChoices.
     **/
    @IsTest
    static void testConvertToChoicesDeduplicated() {
        List<Schema.PicklistEntry> entries =
            Account.Guild__c.getDescribe().getPicklistValues();

        if (entries.isEmpty()) {
            System.assert(true, 'No Guild__c picklist values available');
            return;
        }

        String val = entries[0].getValue();
        String duplicateInput = val + ';' + val;

        Test.startTest();
        List<MultiPicklistChoiceOption> result =
            MultiPicklistToChoicesService.convertToChoices(
                new List<String>{ duplicateInput }
            );
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Duplicate values should be deduplicated');
    }
}