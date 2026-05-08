/**
 * @description       : Handles the execution of the Order trigger logic.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 04-01-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class OrderTriggerHandler {

    private static Boolean isRunning = false;

    /**
     * @description Executes the Order trigger logic, preventing recursive invocations.
     **/
    public static void run() {
        if (isRunning) {
            return;
        }

        isRunning = true;
        try {
            if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
                OrderTriggerLogic.processPelayoOrder(
                    (Map<Id, Order>) Trigger.newMap,
                    (Map<Id, Order>) Trigger.oldMap,
                    Trigger.isInsert,
                    Trigger.isUpdate
                );

                // MKIS ELBA Integration: Create/Update Service + Create Contact
                MKISElbaOrderTriggerLogic.processMKISOrder(
                    (Map<Id, Order>) Trigger.newMap,
                    (Map<Id, Order>) Trigger.oldMap,
                    Trigger.isInsert,
                    Trigger.isUpdate
                );
            }
        } finally {
            isRunning = false;
        }
    }
}