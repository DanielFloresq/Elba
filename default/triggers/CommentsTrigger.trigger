/**
 * @description       : Trigger on Comments__c for Pelayo integration.
 *                      Creates comments in the Pelayo API when "Hito - " prefix is present.
 * @author            : Daniel Flores
 * @group             : Pelayo Integration
 * @last modified on  : 06-04-2026
 * @last modified by  : Daniel Flores
**/
trigger CommentsTrigger on Comments__c (after insert) {
    CommentsTriggerHandler.run();
}