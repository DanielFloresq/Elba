/**
 * @description       : Handles InsurableCoverage__c changes to invoke Pelayo updateClaim.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 05-03-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class PelayoInsurableCoverageTriggerHandler {

    private static Boolean isRunning = false;

    public static void run() {
        if (isRunning) {
            return;
        }

        isRunning = true;
        try {
            if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate || Trigger.isDelete || Trigger.isUndelete)) {
                Set<Id> caseIds = new Set<Id>();
                if (Trigger.isDelete) {
                    for (InsurableCoverage__c cov : (List<InsurableCoverage__c>) Trigger.old) {
                        if (cov != null && cov.Claim__c != null) caseIds.add(cov.Claim__c);
                    }
                } else {
                    for (InsurableCoverage__c cov : (List<InsurableCoverage__c>) Trigger.new) {
                        if (cov != null && cov.Claim__c != null) caseIds.add(cov.Claim__c);
                    }
                }
                PelayoUpdateClaimTriggerLogic.processCaseIds(caseIds);
            }
        } finally {
            isRunning = false;
        }
    }
}