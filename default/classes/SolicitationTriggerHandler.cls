/**
 * @description       : Handles the execution of the Solicitation__c trigger logic for Pelayo integration.
 * @author            : Daniel Flores
 * @group             : Pelayo Integration
 * @last modified on  : 07-04-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class SolicitationTriggerHandler {

    private static Boolean isRunning = false;

    /**
     * @description Entry point for the Solicitation__c trigger. Guards against re-entrancy and delegates to the appropriate handler based on trigger context.
     */
    public static void run() {
        if (isRunning) {
            return;
        }

        isRunning = true;
        try {
            if (Trigger.isAfter && Trigger.isInsert) {
                handleAfterInsert((List<Solicitation__c>) Trigger.new);
            }
        } finally {
            isRunning = false;
        }
    }

    /**
     * @description Handles after-insert logic by collecting new Solicitation IDs and enqueuing a Pelayo notification.
     * @param newSolicitations List of newly inserted Solicitation__c records from Trigger.new.
     */
    @TestVisible
    private static void handleAfterInsert(List<Solicitation__c> newSolicitations) {
        if (newSolicitations == null || newSolicitations.isEmpty()) {
            return;
        }

        List<Id> solicitationIds = new List<Id>();
        for (Solicitation__c solicitation : newSolicitations) {
            if (solicitation != null && solicitation.Id != null) {
                solicitationIds.add(solicitation.Id);
            }
        }

        if (!solicitationIds.isEmpty() && !System.isFuture() && !System.isBatch()) {
            PelayoNotificationService.enqueueCreate(solicitationIds);
        }
    }
}