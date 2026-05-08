/**
 * @description       : Handles Contact changes to invoke Pelayo updateClaim for related Cases.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 15-04-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class PelayoContactUpdateClaimTriggerHandler {

    private static Boolean isRunning = false;

    /**
     * @description Executes the trigger logic: identifies Contacts with relevant field changes and enqueues Pelayo updateClaim for their related open Pelayo Cases.
     **/
    public static void run() {
        if (isRunning) {
            return;
        }

        isRunning = true;
        try {
            if (Trigger.isAfter && Trigger.isUpdate) {
                Map<Id, Contact> newMap = (Map<Id, Contact>) Trigger.newMap;
                Map<Id, Contact> oldMap = (Map<Id, Contact>) Trigger.oldMap;
                if (newMap == null || newMap.isEmpty()) return;

                Set<Id> changedContactIds = new Set<Id>();
                for (Id contactId : newMap.keySet()) {
                    Contact n = newMap.get(contactId);
                    Contact o = oldMap != null ? oldMap.get(contactId) : null;
                    if ((n == null || o == null ) && Trigger.isUpdate) {
                        changedContactIds.add(contactId);
                        continue;
                    }
                    if (o.FirstName != n.FirstName ||
                        o.MiddleName != n.MiddleName ||
                        o.LastName != n.LastName ||
                        o.IDNumber__c != n.IDNumber__c ||
                        o.Email != n.Email ||
                        o.MobilePhone != n.MobilePhone) {
                        changedContactIds.add(contactId);
                    }
                }

                if (changedContactIds.isEmpty()) return;

                Set<Id> caseIds = new Set<Id>();
                for (Case c : [
                    SELECT Id
                    FROM Case
                    WHERE ContactId IN :changedContactIds
                    AND GrandAccount__c = 'PLYO' 
                    AND Status != 'Finished'
                ]) {
                    caseIds.add(c.Id);
                }
                PelayoUpdateClaimTriggerLogic.processCaseIds(caseIds);
            }
        } finally {
            isRunning = false;
        }
    }
}