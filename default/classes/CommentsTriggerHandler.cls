/**
 * @description       : Handles the execution of the Comments__c trigger logic for Pelayo integration.
 *                      Filters comments with "Hito - " prefix and enqueues them for Pelayo notification.
 * @author            : Daniel Flores
 * @group             : Pelayo Integration
 * @last modified on  : 09-04-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class CommentsTriggerHandler {

    private static Boolean isRunning = false;
    private static final String HITO_PREFIX = 'Hito - ';
    private static final String SMS_HITO_PREFIX = 'Hito - Envío de SMS';

    /**
     * @description Executes the trigger logic for Comments__c records, routing after-insert events
     */
    public static void run() {
        if (isRunning) {
            return;
        }

        isRunning = true;
        try {
            if (Trigger.isAfter && Trigger.isInsert) {
                handleAfterInsert((List<Comments__c>) Trigger.new);
            }
        } finally {
            isRunning = false;
        }
    }

    // ─── After Insert ─────────────────────────────────────────────────────────

    /**
     * @description Handles after-insert logic by filtering Hito comments and enqueuing them for Pelayo notification
     * @param newComments List of newly inserted Comments__c records
     */
    @TestVisible
    private static void handleAfterInsert(List<Comments__c> newComments) {
        if (newComments == null || newComments.isEmpty()) {
            return;
        }

        List<Id> hitoCommentIds = filterHitoComments(newComments);

        if (!hitoCommentIds.isEmpty() && !System.isFuture() && !System.isBatch()) {
            PelayoCommentService.enqueueCreate(hitoCommentIds);
        }
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    /**
     * @description Filters comments that have the "Hito - " prefix in Comment__c field.
     * @author Daniel Flores | 06-04-2026
     * @param comments List of Comments__c records to filter
     * @return List<Id> IDs of comments with "Hito - " prefix
     **/
    @TestVisible
    private static List<Id> filterHitoComments(List<Comments__c> comments) {
        List<Id> hitoCommentIds = new List<Id>();

        if (comments == null || comments.isEmpty()) {
            return hitoCommentIds;
        }

        for (Comments__c comm : comments) {
            if (comm.Id != null
               /*  && PelayoCommentService.hasHitoPrefix(comm.Comment__c) */
                && !String.valueOf(comm.Comment__c).startsWith(SMS_HITO_PREFIX)) {
                hitoCommentIds.add(comm.Id);
            }
        }

        return hitoCommentIds;
    }
}