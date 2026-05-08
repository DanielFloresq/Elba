trigger ContactUpdateClaimTrigger on Contact (after update) {
    PelayoContactUpdateClaimTriggerHandler.run();
}