trigger CaseUpdateClaimTrigger on Case (after insert, after update) {
    PelayoUpdateClaimTriggerHandler.run();
}