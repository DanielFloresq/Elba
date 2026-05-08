/**
 * @description       : Trigger on ContentDocumentLink for MKIS ELBA integration.
 *                      Sends attachments to MKIS ELBA API when files are linked to Orders.
 * @author            : Daniel Flores
 * @group             : MKIS Integration
 * @last modified on  : 26-03-2026
 * @last modified by  : Daniel Flores
**/
trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert) {
    ContentDocumentLinkTriggerHandler.run();
}