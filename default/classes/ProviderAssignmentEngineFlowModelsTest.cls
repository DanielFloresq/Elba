/**
 * @description       : Test class for ProviderAssignmentEngineFlowModels.
 *                      Validates that the Flow / LWC-exposed inner DTOs can be instantiated
 *                      and field-assigned. These classes are accessed by Flow and Lightning
 *                      via @InvocableVariable / @AuraEnabled — pure structural coverage.
 * @author            : Test Class Builder
 * @group             : Provider Assignment
**/
@IsTest
private class ProviderAssignmentEngineFlowModelsTest {

    @IsTest
    static void flowProviderSnapshot_canBeInstantiatedAndAssigned() {
        Account a = new Account(Name = 'Provider Account');
        insert a;

        ProviderAssignmentEngineFlowModels.FlowProviderSnapshot snap =
            new ProviderAssignmentEngineFlowModels.FlowProviderSnapshot();

        snap.providerId = a.Id;
        snap.providerName = 'Provider Test';
        snap.score = 42.5;
        snap.eligible = true;
        snap.reason = 'OK';
        snap.selectionDetails = 'matched first';
        snap.warnings = new List<String>{ 'minor warning' };
        snap.failureStage = null;

        Test.startTest();
        // Round-trip through serialization to confirm the public shape is JSON-stable
        String json = JSON.serialize(snap);
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(json);
        Test.stopTest();

        System.assertEquals(a.Id, snap.providerId, 'providerId should round-trip');
        System.assertEquals(42.5, snap.score, 'score should round-trip');
        System.assertEquals(true, snap.eligible, 'eligible should round-trip');
        System.assertEquals(1, snap.warnings.size(), 'warnings list should be preserved');
        System.assert(parsed.containsKey('providerId'),
            'JSON output should expose providerId for downstream consumers');
    }

    @IsTest
    static void flowProviderSnapshot_warningsDefault_isEmptyList() {
        ProviderAssignmentEngineFlowModels.FlowProviderSnapshot snap =
            new ProviderAssignmentEngineFlowModels.FlowProviderSnapshot();

        Test.startTest();
        Boolean isEmpty = snap.warnings != null && snap.warnings.isEmpty();
        Test.stopTest();

        System.assertEquals(true, isEmpty,
            'Default warnings list should be initialised to an empty list');
    }

    @IsTest
    static void flowManualFeedback_canBeInstantiatedAndAssigned() {
        Account a = new Account(Name = 'Feedback Account');
        insert a;

        ProviderAssignmentEngineFlowModels.FlowManualFeedback fb =
            new ProviderAssignmentEngineFlowModels.FlowManualFeedback();

        fb.providerId = a.Id;
        fb.reason = 'Manual override reason';

        Test.startTest();
        String json = JSON.serialize(fb);
        Test.stopTest();

        System.assertEquals(a.Id, fb.providerId, 'providerId should be set');
        System.assertEquals('Manual override reason', fb.reason, 'reason should be set');
        System.assert(json.contains('Manual override reason'),
            'Serialized payload should include the reason field');
    }
}
