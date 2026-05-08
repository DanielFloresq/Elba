/**
 * @description       : Handles Create Attachments calls to MKIS ELBA API.
 *                      Triggered when a ContentDocumentLink is created for an Order.
 * @author            : Daniel Flores
 * @group             : MKIS Integration
 * @last modified on  : 06-05-2026
 * @last modified by  : Daniel Flores
**/
public without sharing class MKISElbaAttachmentHandler {

    private static final String ENDPOINT_ATTACHMENTS = '/attachments';

    /**
    * @description Sends attachments to MKIS ELBA when ContentDocumentLinks are created for Orders.
    * @param cdlIds List of ContentDocumentLink Ids to process
    **/
    @future(callout=true)
    public static void createAttachmentsAsync(Set<Id> cdlIds) {
        // Query ContentDocumentLinks with their documents
        List<ContentDocumentLink> cdls = [
            SELECT Id, ContentDocumentId, LinkedEntityId,
                   ContentDocument.LatestPublishedVersion.Title,
                   ContentDocument.LatestPublishedVersion.VersionData,
                   ContentDocument.LatestPublishedVersion.FileType
            FROM ContentDocumentLink
            WHERE Id IN :cdlIds
        ];

        // Group by Order Id
        Map<Id, List<ContentDocumentLink>> cdlsByOrder = new Map<Id, List<ContentDocumentLink>>();
        for (ContentDocumentLink cdl : cdls) {
            Id linkedId = cdl.LinkedEntityId;
            if (!cdlsByOrder.containsKey(linkedId)) {
                cdlsByOrder.put(linkedId, new List<ContentDocumentLink>());
            }
            cdlsByOrder.get(linkedId).add(cdl);
        }

        // Send attachments per Order
        for (Id orderId : cdlsByOrder.keySet()) {
            sendAttachments(orderId, cdlsByOrder.get(orderId));
        }
    }

    /**
    * @description Sends attachments for a specific Order to MKIS ELBA.
    **/
    private static void sendAttachments(Id orderId, List<ContentDocumentLink> cdls) {
        MKISElbaStructures.CreateAttachmentRequest req = new MKISElbaStructures.CreateAttachmentRequest();
        req.order_id = String.valueOf(orderId);
        req.attachments = new List<MKISElbaStructures.AttachmentItem>();

        for (ContentDocumentLink cdl : cdls) {
            if (cdl.ContentDocument != null && cdl.ContentDocument.LatestPublishedVersion != null) {
                MKISElbaStructures.AttachmentItem att = new MKISElbaStructures.AttachmentItem();
                att.name = cdl.ContentDocument.LatestPublishedVersion.Title;
                if (cdl.ContentDocument.LatestPublishedVersion.VersionData != null) {
                    att.content = EncodingUtil.base64Encode(cdl.ContentDocument.LatestPublishedVersion.VersionData);
                }
                req.attachments.add(att);
            }
        }

        if (!req.attachments.isEmpty()) {
            String body = JSON.serialize(req, true);

            try {
                HttpResponse res = MKISElbaCalloutService.doPost(ENDPOINT_ATTACHMENTS, body);
                System.debug('MKIS Create Attachments response: ' + res.getStatusCode() + ' - ' + res.getBody());
                /* sendResponseEvent(orderId, res.getStatusCode() == 200, res.getBody()); */
            } catch (Exception e) {
                System.debug('MKIS Create Attachments error: ' + e.getMessage());
              /*   sendResponseEvent(orderId, false, e.getMessage()); */
            }
        }
    }

    /**
    * @description Publishes a PopUP_Service__e platform event with the integration result.
    * @param recordId The Order Id
    * @param isSuccess Whether the API call was successful
    * @param message The response message
    **/
    private static void sendResponseEvent(Id recordId, Boolean isSuccess, String message) {
        PopUP_Service__e responseEvent = new PopUP_Service__e(
            RecordId__c = String.valueOf(recordId),
            Message__c = message,
            Success__c = isSuccess
        );
        EventBus.publish(responseEvent);
    }
}