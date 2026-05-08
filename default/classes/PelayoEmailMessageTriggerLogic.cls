/**
 * @description       : Determines when to invoke Pelayo communications for EmailMessage records.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 01-04-2026
 * @last modified by  : Daniel Flores
**/
public without sharing class PelayoEmailMessageTriggerLogic {

    private static final Set<String> SENT_EMAIL_STATUSES = new Set<String>{ '3', 'sent', 'enviado' };

    @TestVisible
    public static Boolean bypassExternalActions = false;

    public static void processEmailMessages(
        Map<Id, EmailMessage> newMap,
        Map<Id, EmailMessage> oldMap,
        Boolean isInsert,
        Boolean isUpdate
    ) {
        if (bypassExternalActions || newMap == null || newMap.isEmpty()) {
            return;
        }

        Set<Id> emailMessageIdsToSend = new Set<Id>();
        for (EmailMessage emNew : newMap.values()) {
            if (emNew == null) {
                continue;
            }
            if (emNew.ParentId == null && emNew.RelatedToId == null) {
                continue;
            }
            if (!isSentEmailMessage(emNew)) {
                continue;
            }

            if (isInsert) {
                emailMessageIdsToSend.add(emNew.Id);
                continue;
            }

            EmailMessage emOld = oldMap != null ? oldMap.get(emNew.Id) : null;
            if (emOld == null
                || !isSentEmailMessage(emOld)
                || isRelevantEmailChange(emOld, emNew)) {
                emailMessageIdsToSend.add(emNew.Id);
            }
        }

        if (!emailMessageIdsToSend.isEmpty()) {
            PelayoCommunicationService.enqueueEmails(emailMessageIdsToSend);
        }
    }

    @TestVisible
    static Boolean isRelevantEmailChange(EmailMessage oldEm, EmailMessage newEm) {
        return oldEm.ParentId != newEm.ParentId
            || oldEm.RelatedToId != newEm.RelatedToId
            || oldEm.Incoming != newEm.Incoming
            || oldEm.Status != newEm.Status
            || oldEm.Recipient__c != newEm.Recipient__c;
    }

    @TestVisible
    static Boolean isSentEmailMessage(EmailMessage emailMessage) {
        if (emailMessage == null || emailMessage.Incoming) {
            return false;
        }

        String normalizedStatus = String.valueOf(emailMessage.Status).trim().toLowerCase();
        return SENT_EMAIL_STATUSES.contains(normalizedStatus);
    }
}