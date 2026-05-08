/**
 * @description       : Data model representing a single choice option for multi-picklist conversion
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 14-01-2026
 * @last modified by  : Daniel Flores
 **/
public class MultiPicklistChoiceOption {
    @InvocableVariable(label='Value' description='API Name do valor do picklist')
    @AuraEnabled
    public String value;

    @InvocableVariable(label='Label' description='Label visível ao utilizador')
    @AuraEnabled
    public String label;

    public MultiPicklistChoiceOption() {
    }

    public MultiPicklistChoiceOption(String value, String label) {
        this.value = value;
        this.label = label;
    }
}