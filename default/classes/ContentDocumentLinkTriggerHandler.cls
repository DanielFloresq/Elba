/**
 * @description       : Handles the execution of the ContentDocumentLink trigger logic.
 *                      Filters CDLs linked to Orders and sends attachments to MKIS ELBA API.
 * @author            : Daniel Flores
 * @group             : MKIS Integration
 * @last modified on  : 04-01-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class ContentDocumentLinkTriggerHandler {

    private static final String ORDER_KEY_PREFIX = '801';

    private static Boolean isRunning = false;

    /**
     * @description Executes the trigger logic for ContentDocumentLink records
     */
    public static void run() {
        if (isRunning) {
            return;
        }
        isRunning = true;
        try {
            if (Trigger.isAfter && Trigger.isInsert) {
                Set<Id> orderRelatedCdlIds = new Set<Id>();

                for (ContentDocumentLink cdl : (List<ContentDocumentLink>) Trigger.new) {
                    // Check if the linked entity is an Order (KeyPrefix 801)
                    String linkedEntityIdStr = String.valueOf(cdl.LinkedEntityId);
                    if (linkedEntityIdStr != null && linkedEntityIdStr.startsWith(ORDER_KEY_PREFIX)) {
                        orderRelatedCdlIds.add(cdl.Id);
                    }
                }

                if (!orderRelatedCdlIds.isEmpty() && !System.isFuture() && !System.isBatch()) {
                    MKISElbaAttachmentHandler.createAttachmentsAsync(orderRelatedCdlIds);
                }
            }
        } finally {
            isRunning = false;
        }
    }
}