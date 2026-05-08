/**
 * @description       : Handles the execution of Case trigger logic for Pelayo updateClaim.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 05-03-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class PelayoUpdateClaimTriggerHandler {

    private static Boolean isRunning = false;

    /**
     * @description Trigger handler entry point. Delegates to PelayoUpdateClaimTriggerLogic to evaluate Case changes and enqueue Pelayo updateClaim callouts when relevant fields are modified.
     **/
    public static void run() {
        if (isRunning) {
            return;
        }

        isRunning = true;
        try {
            if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
                PelayoUpdateClaimTriggerLogic.processCases(
                    (Map<Id, Case>) Trigger.newMap,
                    (Map<Id, Case>) Trigger.oldMap,
                    Trigger.isInsert,
                    Trigger.isUpdate
                );
            }
        } finally {
            isRunning = false;
        }
    }
}