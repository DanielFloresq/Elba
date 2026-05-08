public class ProviderAssignmentEngineFlowModels {
    public class FlowProviderSnapshot {
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

    public class FlowManualFeedback {
        @InvocableVariable
        @AuraEnabled
        public Id providerId;
        @InvocableVariable
        @AuraEnabled
        public String reason;
    }
}