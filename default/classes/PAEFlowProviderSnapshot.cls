/**
 * @description Flow-invocable data model representing a provider snapshot for assignment engine results
 * @author Daniel Flores
 * @group
 * @last modified on 14-01-2026
 * @last modified by Daniel Flores
 */
public class PAEFlowProviderSnapshot {
    @InvocableVariable
    @AuraEnabled
    public Id providerId;
    @InvocableVariable
    @AuraEnabled
    public String providerName;
    @InvocableVariable
    @AuraEnabled
    public Decimal score;
    @InvocableVariable
    @AuraEnabled
    public Boolean eligible;
    @InvocableVariable
    @AuraEnabled
    public String reason;
    @InvocableVariable
    @AuraEnabled
    public String selectionDetails;
    @InvocableVariable
    @AuraEnabled
    public List<String> warnings = new List<String>();
    @InvocableVariable
    @AuraEnabled
    public String failureStage;
}