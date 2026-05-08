/**
 * @description       : Service for converting multi-picklist field values into structured choice options
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 14-01-2026
 * @last modified by  : Daniel Flores
 **/
public with sharing class MultiPicklistToChoicesService {
    private static final Schema.DescribeFieldResult GUILD_FIELD_DESCRIBE = Account.Guild__c.getDescribe();

    /**
     * @description Converts one or more Multi-Select Picklist strings into a collection of choice options for Flow.
     *              Each input string may contain multiple values separated by ';'.
     * @param multiPicklistValues List of semicolon-separated picklist value strings
     * @return List of MultiPicklistChoiceOption with value/label pairs
     */
    @InvocableMethod(
        label='Multi Picklist To Choices'
        description='Converte valores de Multi-Select Picklist em opções value/label para Flow.'
    )
    public static List<MultiPicklistChoiceOption> convertToChoices(List<String> multiPicklistValues) {
        List<MultiPicklistChoiceOption> results = new List<MultiPicklistChoiceOption>();
        if (multiPicklistValues == null || multiPicklistValues.isEmpty()) {
            return results;
        }

        Map<String, String> labelsByValue = getLabelsByValue();

        for (String rawValueSet : multiPicklistValues) {
            results.addAll(buildChoices(rawValueSet, labelsByValue));
        }

        return results;
    }

    /**
     * @description Retrieves a map of picklist API values to their display labels from the Guild field describe.
     * @return Map of picklist value to label
     */
    private static Map<String, String> getLabelsByValue() {
        Map<String, String> labelsByValue = new Map<String, String>();
        for (Schema.PicklistEntry entry : GUILD_FIELD_DESCRIBE.getPicklistValues()) {
            labelsByValue.put(entry.getValue(), entry.getLabel());
        }
        return labelsByValue;
    }

    /**
     * @description Builds a deduplicated list of MultiPicklistChoiceOption from a semicolon-separated value string.
     * @param rawValueSet Semicolon-separated picklist values
     * @param labelsByValue Map of picklist value to label
     * @return List of MultiPicklistChoiceOption
     */
    private static List<MultiPicklistChoiceOption> buildChoices(String rawValueSet, Map<String, String> labelsByValue) {
        List<MultiPicklistChoiceOption> choices = new List<MultiPicklistChoiceOption>();
        if (String.isBlank(rawValueSet)) {
            return choices;
        }

        Set<String> seenValues = new Set<String>();
        for (String token : rawValueSet.split(';')) {
            String normalizedValue = token == null ? null : token.trim();
            if (String.isBlank(normalizedValue) || seenValues.contains(normalizedValue)) {
                continue;
            }

            seenValues.add(normalizedValue);
            choices.add(new MultiPicklistChoiceOption(
                normalizedValue,
                labelsByValue.containsKey(normalizedValue) ? labelsByValue.get(normalizedValue) : normalizedValue
            ));
        }

        return choices;
    }
}