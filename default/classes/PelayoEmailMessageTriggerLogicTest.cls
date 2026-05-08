/**
 * @description       : Test class for PelayoEmailMessageTriggerLogic.
 *                      Covers processEmailMessages bypass + insert/update branches,
 *                      isSentEmailMessage status normalization, isRelevantEmailChange
 *                      field-by-field, and bulk safety. Asserts via Limits.getQueueableJobs
 *                      from the downstream PelayoCommunicationService.enqueueEmails enqueue.
 * @author            : Test Class Builder
 * @group             : Pelayo Integration
**/
@IsTest
private class PelayoEmailMessageTriggerLogicTest {

    private static final String PELAYO_GRAND_ACCOUNT = 'PLYO';

    @TestSetup
    static void setupTestData() {
        TestFactory.createAccount(
            'Email Trigger Account',
            PELAYO_GRAND_ACCOUNT,
            'A2',
            'Customer'
        );
        Case pelayoCase = new Case(
            Subject = 'Email Trigger Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = PELAYO_GRAND_ACCOUNT
        );
        insert pelayoCase;
    }

    private static Case getCase() { return [SELECT Id FROM Case LIMIT 1]; }

    private static EmailMessage buildEmail(Id parentId, String status, Boolean incoming) {
        return new EmailMessage(
            ParentId = parentId,
            Subject = 'Test',
            TextBody = 'Body',
            FromAddress = 'a@test.com',
            ToAddress = 'b@test.com',
            Incoming = incoming,
            Status = status,
            MessageDate = Datetime.now()
        );
    }

    // ─── isSentEmailMessage ──────────────────────────────────────────────────

    @IsTest
    static void isSentEmailMessage_status3_returnsTrue() {
        EmailMessage em = buildEmail(getCase().Id, '3', false);
        Test.startTest();
        Boolean result = PelayoEmailMessageTriggerLogic.isSentEmailMessage(em);
        Test.stopTest();
        System.assertEquals(true, result, 'Status "3" should be treated as sent');
    }

    @IsTest
    static void isSentEmailMessage_statusSent_returnsTrue() {
        EmailMessage em = buildEmail(getCase().Id, 'sent', false);
        Test.startTest();
        Boolean result = PelayoEmailMessageTriggerLogic.isSentEmailMessage(em);
        Test.stopTest();
        System.assertEquals(true, result, 'Status "sent" should be treated as sent');
    }

    @IsTest
    static void isSentEmailMessage_statusEnviado_returnsTrue() {
        EmailMessage em = buildEmail(getCase().Id, 'enviado', false);
        Test.startTest();
        Boolean result = PelayoEmailMessageTriggerLogic.isSentEmailMessage(em);
        Test.stopTest();
        System.assertEquals(true, result, 'Status "enviado" should be treated as sent');
    }

    @IsTest
    static void isSentEmailMessage_incoming_returnsFalse() {
        EmailMessage em = buildEmail(getCase().Id, '3', true);
        Test.startTest();
        Boolean result = PelayoEmailMessageTriggerLogic.isSentEmailMessage(em);
        Test.stopTest();
        System.assertEquals(false, result, 'Incoming emails are never "sent"');
    }

    @IsTest
    static void isSentEmailMessage_otherStatus_returnsFalse() {
        EmailMessage em = buildEmail(getCase().Id, '0', false);
        Test.startTest();
        Boolean result = PelayoEmailMessageTriggerLogic.isSentEmailMessage(em);
        Test.stopTest();
        System.assertEquals(false, result, 'Non-sent status should return false');
    }

    @IsTest
    static void isSentEmailMessage_null_returnsFalse() {
        Test.startTest();
        Boolean result = PelayoEmailMessageTriggerLogic.isSentEmailMessage(null);
        Test.stopTest();
        System.assertEquals(false, result, 'Null email must return false');
    }

    // ─── isRelevantEmailChange ───────────────────────────────────────────────

    @IsTest
    static void isRelevantEmailChange_statusChanged_returnsTrue() {
        EmailMessage oldEm = buildEmail(getCase().Id, '0', false);
        EmailMessage newEm = buildEmail(getCase().Id, '3', false);

        Test.startTest();
        Boolean result = PelayoEmailMessageTriggerLogic.isRelevantEmailChange(oldEm, newEm);
        Test.stopTest();

        System.assertEquals(true, result, 'Status change should be relevant');
    }

    @IsTest
    static void isRelevantEmailChange_noChange_returnsFalse() {
        EmailMessage oldEm = buildEmail(getCase().Id, '3', false);
        EmailMessage newEm = buildEmail(getCase().Id, '3', false);

        Test.startTest();
        Boolean result = PelayoEmailMessageTriggerLogic.isRelevantEmailChange(oldEm, newEm);
        Test.stopTest();

        System.assertEquals(false, result, 'Identical emails are not relevant');
    }

    // ─── processEmailMessages ────────────────────────────────────────────────

    @IsTest
    static void processEmailMessages_bypass_returnsEarly() {
        EmailMessage em = buildEmail(getCase().Id, '3', false);
        em.Id = '02s000000000001AAA'; // synthesised id for the map

        PelayoEmailMessageTriggerLogic.bypassExternalActions = true;

        Test.startTest();
        PelayoEmailMessageTriggerLogic.processEmailMessages(
            new Map<Id, EmailMessage>{ em.Id => em }, null, true, false
        );
        Test.stopTest();

        System.assertEquals(0, Limits.getQueueableJobs(),
            'Bypass true should skip enqueueEmails');
    }

    @IsTest
    static void processEmailMessages_nullOrEmpty_returnsEarly() {
        PelayoEmailMessageTriggerLogic.bypassExternalActions = false;

        Test.startTest();
        PelayoEmailMessageTriggerLogic.processEmailMessages(null, null, true, false);
        PelayoEmailMessageTriggerLogic.processEmailMessages(
            new Map<Id, EmailMessage>(), null, true, false
        );
        Test.stopTest();

        System.assertEquals(0, Limits.getQueueableJobs(), 'Null/empty newMap is a no-op');
    }

    @IsTest
    static void processEmailMessages_insertSentEmail_enqueuesCommunication() {
        Case c = getCase();
        EmailMessage em = buildEmail(c.Id, '3', false);
        insert em;
        em = [SELECT Id, ParentId, RelatedToId, Incoming, Status, Recipient__c
              FROM EmailMessage WHERE Id = :em.Id LIMIT 1];

        PelayoEmailMessageTriggerLogic.bypassExternalActions = false;

        Test.startTest();
        PelayoEmailMessageTriggerLogic.processEmailMessages(
            new Map<Id, EmailMessage>{ em.Id => em }, null, true, false
        );
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            'Insert of a sent EmailMessage with ParentId should enqueue communication');
    }

    @IsTest
    static void processEmailMessages_emailNoParent_skipped() {
        EmailMessage em = new EmailMessage(
            Subject = 'Orphan',
            TextBody = 'No parent',
            FromAddress = 'a@test.com',
            ToAddress = 'b@test.com',
            Incoming = false,
            Status = '3'
        );
        em.Id = '02s000000000099AAA';

        PelayoEmailMessageTriggerLogic.bypassExternalActions = false;

        Test.startTest();
        PelayoEmailMessageTriggerLogic.processEmailMessages(
            new Map<Id, EmailMessage>{ em.Id => em }, null, true, false
        );
        Test.stopTest();

        System.assertEquals(0, Limits.getQueueableJobs(),
            'Email without ParentId/RelatedToId must be skipped');
    }

    @IsTest
    static void processEmailMessages_updateNoStatusChange_skipped() {
        Case c = getCase();
        EmailMessage em = buildEmail(c.Id, '3', false);
        insert em;
        em = [SELECT Id, ParentId, RelatedToId, Incoming, Status, Recipient__c
              FROM EmailMessage WHERE Id = :em.Id LIMIT 1];
        EmailMessage same = em.clone(true, true, true, true);

        PelayoEmailMessageTriggerLogic.bypassExternalActions = false;

        Test.startTest();
        PelayoEmailMessageTriggerLogic.processEmailMessages(
            new Map<Id, EmailMessage>{ em.Id => em },
            new Map<Id, EmailMessage>{ same.Id => same },
            false, true
        );
        Test.stopTest();

        System.assertEquals(0, Limits.getQueueableJobs(),
            'Update of an already-sent email with no relevant change must not enqueue');
    }

    // ─── Bulk safety ─────────────────────────────────────────────────────────

    @IsTest
    static void processEmailMessages_bulk200_singleEnqueue() {
        Case c = getCase();
        List<EmailMessage> bulk = new List<EmailMessage>();
        for (Integer i = 0; i < 200; i++) {
            bulk.add(buildEmail(c.Id, '3', false));
        }
        insert bulk;
        Map<Id, EmailMessage> newMap = new Map<Id, EmailMessage>([
            SELECT Id, ParentId, RelatedToId, Incoming, Status, Recipient__c
            FROM EmailMessage WHERE Id IN :bulk
        ]);

        PelayoEmailMessageTriggerLogic.bypassExternalActions = false;

        Test.startTest();
        PelayoEmailMessageTriggerLogic.processEmailMessages(newMap, null, true, false);
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued,
            '200-record bulk should still produce exactly one Queueable');
    }
}
