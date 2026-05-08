/**
 * @description       : Handles Stakeholders__c changes to invoke Pelayo updateClaim.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 15-04-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class PelayoStakeholdersTriggerHandler {

    private static Boolean isRunning = false;

    private static final String PELAYO_ACCOUNT_CODE = 'PLYO';
    private static final String PELAYO_INTEGRATION_USER_NAME = 'Pelayo Integration';

    @TestVisible
    static Boolean treatCurrentUserAsIntegrationUser;

    private static Boolean cachedIsIntegrationUser;

    /**
     * @description Entry point invoked from the Stakeholders__c trigger. Collects affected Case Ids and delegates to PelayoUpdateClaimTriggerLogic for updateClaim processing. Uses a static guard to prevent re-entrant execution.
     */
    public static void run() {
        if (isRunning) {
            return;
        }

        if (!shouldRunInContext()) {
            return;
        }

        isRunning = true;
        try {
            if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate || Trigger.isDelete )) {
                Set<Id> caseIds = new Set<Id>();
                if (Trigger.isDelete) {
                    for (Stakeholders__c s : (List<Stakeholders__c>) Trigger.old) {
                        if (s != null && s.Case__c != null) caseIds.add(s.Case__c);
                    }
                } else {
                    for (Stakeholders__c s : (List<Stakeholders__c>) Trigger.new) {
                        if (s != null && s.Case__c != null) caseIds.add(s.Case__c);
                    }
                }

                Set<Id> pelayoCaseIds = filterPelayoCaseIds(caseIds);
                PelayoUpdateClaimTriggerLogic.processCaseIds(pelayoCaseIds);
            }
        } finally {
            isRunning = false;
        }
    }

    private static Boolean shouldRunInContext() {
        if (treatCurrentUserAsIntegrationUser == true) {
            return false;
        }
        return !isIntegrationUser();
    }

    private static Boolean isIntegrationUser() {
        if (cachedIsIntegrationUser != null) {
            return cachedIsIntegrationUser;
        }

        String currentUserName;
        try {
            currentUserName = [SELECT Name FROM User WHERE Id = :UserInfo.getUserId()].Name;
        } catch (Exception e) {
            currentUserName = null;
        }

        cachedIsIntegrationUser = (currentUserName == PELAYO_INTEGRATION_USER_NAME);
        return cachedIsIntegrationUser;
    }

    private static Set<Id> filterPelayoCaseIds(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return new Set<Id>();
        }

        Set<Id> pelayoCaseIds = new Set<Id>();
        for (Case c : [
            SELECT Id
            FROM Case
            WHERE Id IN :caseIds
            AND GrandAccount__c = :PELAYO_ACCOUNT_CODE
        ]) {
            pelayoCaseIds.add(c.Id);
        }
        return pelayoCaseIds;
    }
}