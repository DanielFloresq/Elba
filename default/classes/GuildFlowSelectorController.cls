/**
 * @description       : Controller for retrieving available guild options with supplier exclusion filtering
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 05-05-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class GuildFlowSelectorController {
    private static final Schema.DescribeFieldResult GUILD_FIELD_DESCRIBE = Service__c.Type__c.getDescribe();

    /**
     * @description Retrieves available guild options filtered by supplier exclusions, existing services, and provider guilds
     * @param providerId The Id of the provider account to filter guild options against
     * @param guildValues Semicolon-separated string of guild values to consider
     * @param relatedAccountIds List of related account Ids to retrieve additional guild values from
     * @param relatedServiceIds List of related service Ids to exclude already existing service types
     * @return List of MultiPicklistChoiceOption representing the available guild options
     */
    @AuraEnabled(cacheable=true)
    public static List<MultiPicklistChoiceOption> getAvailableGuildOptions(
        Id providerId,
        String guildValues,
        List<Id> relatedAccountIds,
        List<Id> relatedServiceIds,
        String stakeHolderSelected
    ) {
        Set<String> availableGuilds = splitValues(guildValues);
        if ((availableGuilds == null || availableGuilds.isEmpty()) && relatedAccountIds != null && !relatedAccountIds.isEmpty()) {
            for (Account acc : [
                SELECT Guild__c
                FROM Account
                WHERE Id IN :relatedAccountIds
            ]) {
                availableGuilds.addAll(splitValues(acc.Guild__c));
            }
        }

        if (availableGuilds.isEmpty()) {
            return new List<MultiPicklistChoiceOption>();
        }

        Set<String> existingServiceTypes = new Set<String>();
        if (relatedServiceIds != null && !relatedServiceIds.isEmpty()) {
            for (Service__c service : [
                SELECT Type__c
                FROM Service__c
                WHERE Id IN :relatedServiceIds
                AND Status__c != 'Cancelled'
                AND Type__c != null
                AND Stakeholder__r.Id = :stakeHolderSelected
            ]) {
                existingServiceTypes.add(service.Type__c);
            }
        }

        if (providerId != null) {
            Account provider = [
                SELECT Guild__c
                FROM Account
                WHERE Id = :providerId
                LIMIT 1
            ];

            Set<String> providerGuilds = splitValues(provider.Guild__c);
            providerGuilds.removeAll(getActiveSupplierGuildExclusions(providerId, availableGuilds));
            availableGuilds.retainAll(providerGuilds);
        }

        availableGuilds.removeAll(existingServiceTypes);
        return toOptions(availableGuilds);
    }

    /**
     * @description Queries active SupplierGuild records for the given provider and returns guild types to exclude
     * @param providerId The Id of the provider account
     * @param availableGuilds Set of guild values to check exclusions against
     * @return Set of guild type strings that should be excluded
     */
    private static Set<String> getActiveSupplierGuildExclusions(Id providerId, Set<String> availableGuilds) {
        Set<String> excludedGuilds = new Set<String>();
        if (providerId == null || availableGuilds == null || availableGuilds.isEmpty()) {
            return excludedGuilds;
        }

        for (SupplierGuild__c supplierGuild : [
            SELECT Type__c
            FROM SupplierGuild__c
            WHERE Account__c = :providerId
            AND Status__c = 'Active'
            AND Type__c IN :availableGuilds
        ]) {
            if (!String.isBlank(supplierGuild.Type__c)) {
                excludedGuilds.add(supplierGuild.Type__c);
            }
        }

        return excludedGuilds;
    }

    /**
     * @description Splits a semicolon-separated string into a set of trimmed non-blank values
     * @param rawValues The semicolon-separated string to split
     * @return Set of individual trimmed values
     */
    private static Set<String> splitValues(String rawValues) {
        Set<String> values = new Set<String>();
        if (String.isBlank(rawValues)) {
            return values;
        }

        for (String token : rawValues.split(';')) {
            String normalizedValue = token == null ? null : token.trim();
            if (!String.isBlank(normalizedValue)) {
                values.add(normalizedValue);
            }
        }

        return values;
    }

    /**
     * @description Converts a set of picklist values into sorted MultiPicklistChoiceOption instances with labels
     * @param values Set of picklist API values to convert
     * @return Sorted list of MultiPicklistChoiceOption with value and label pairs
     */
    private static List<MultiPicklistChoiceOption> toOptions(Set<String> values) {
        Map<String, String> labelsByValue = new Map<String, String>();
        for (Schema.PicklistEntry entry : GUILD_FIELD_DESCRIBE.getPicklistValues()) {
            labelsByValue.put(entry.getValue(), entry.getLabel());
        }

        List<String> sortedValues = new List<String>(values);
        sortedValues.sort();

        List<MultiPicklistChoiceOption> options = new List<MultiPicklistChoiceOption>();
        for (String value : sortedValues) {
            options.add(new MultiPicklistChoiceOption(
                value,
                labelsByValue.containsKey(value) ? labelsByValue.get(value) : value
            ));
        }
        return options;
    }
}