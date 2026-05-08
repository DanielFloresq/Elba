/**
 * @description       : Handles Create Message calls to MKIS ELBA API.
 *                      Called from ElbaChatMessageOrderController when a message is sent.
 * @author            : Daniel Flores
 * @group             : MKIS Integration
 * @last modified on  : 26-03-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class MKISElbaMessageHandler {

    private static final String ENDPOINT_MESSAGES = '/messages';

    /**
    * @description Sends a message to MKIS ELBA API.
    * @param orderId The Order Id the message is related to
    * @param messageBody The message body text
    * @param files List of file attachments (from the chat component)
    * @return Boolean true if successful
    **/
    public static Boolean sendMessage(String orderId, String messageBody, List<ElbaChatMessageOrderController.File> files) {
        MKISElbaStructures.CreateMessageRequest req = new MKISElbaStructures.CreateMessageRequest();
        req.order_id = orderId;
        req.body = messageBody;

        if (files != null && !files.isEmpty()) {
            req.attachments = new List<MKISElbaStructures.AttachmentItem>();
            for (ElbaChatMessageOrderController.File f : files) {
                MKISElbaStructures.AttachmentItem att = new MKISElbaStructures.AttachmentItem();
                att.name = f.fileName;
                att.content = f.fileBody;
                req.attachments.add(att);
            }
        }

        String body = JSON.serialize(req, true);

        try {
            HttpResponse res = MKISElbaCalloutService.doPost(ENDPOINT_MESSAGES, body);
            System.debug('MKIS Create Message response: ' + res.getStatusCode() + ' - ' + res.getBody());
            Boolean success = res.getStatusCode() == 200;
            sendResponseEvent((Id) orderId, success, res.getBody());
            return success;
        } catch (Exception e) {
            System.debug('MKIS Create Message error: ' + e.getMessage());
            sendResponseEvent((Id) orderId, false, e.getMessage());
            return false;
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