/**
 * @description       : Handles EmailMessage trigger execution.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 01-04-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class EmailMessageTriggerHandler {

    private static Boolean isRunning = false;

    /**
     * @description Executes the EmailMessage trigger logic with re-entrancy guard, delegating to PelayoEmailMessageTriggerLogic for after insert/update events
     */
    public static void run() {
        if (isRunning) {
            return;
        }

        isRunning = true;
        try {
            if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
                PelayoEmailMessageTriggerLogic.processEmailMessages(
                    (Map<Id, EmailMessage>) Trigger.newMap,
                    (Map<Id, EmailMessage>) Trigger.oldMap,
                    Trigger.isInsert,
                    Trigger.isUpdate
                );
            }
        } finally {
            isRunning = false;
        }
    }
}