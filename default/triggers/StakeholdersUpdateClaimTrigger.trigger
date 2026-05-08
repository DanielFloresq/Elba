/**
 * @description       : 
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 07-05-2026
 * @last modified by  : Daniel Flores
**/
trigger StakeholdersUpdateClaimTrigger on Stakeholders__c (after insert, after update) {
    PelayoStakeholdersTriggerHandler.run();

    if (!System.isFuture() && !System.isBatch()) {
        if (Trigger.isInsert) {
            MKISElbaStakeholderHandler.createStakeholderAsync(new List<Id>(Trigger.newMap.keySet()));
        } else if (Trigger.isUpdate) {
            MKISElbaStakeholderHandler.updateStakeholderAsync(new List<Id>(Trigger.newMap.keySet()));
        } else if (Trigger.isDelete) {
            List<String> mkisIds = new List<String>();
            for (Stakeholders__c s : Trigger.old) {
                if (String.isNotBlank(s.MKISId__c)) {
                    mkisIds.add(s.MKISId__c);
                }
            }
            if (!mkisIds.isEmpty()) {
                MKISElbaStakeholderHandler.deleteStakeholderAsync(mkisIds);
            }
        }
    }
}