/**
 * @description Flow-invocable data model for manual feedback during provider assignment
 * @author Daniel Flores
 * @group
 * @last modified on 14-01-2026
 * @last modified by Daniel Flores
 */
public class PAEFlowManualFeedback {
    @InvocableVariable
    @AuraEnabled
    public Id providerId;
    @InvocableVariable
    @AuraEnabled
    public String reason;
}