/**
 * @description       : Trigger for Pelayo email communications.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 01-04-2026
 * @last modified by  : Daniel Flores
**/
trigger EmailMessageTrigger on EmailMessage (after insert, after update) {
    EmailMessageTriggerHandler.run();
}