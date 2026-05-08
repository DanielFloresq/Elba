/**
 * @description       : 
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 24-02-2026
 * @last modified by  : Daniel Flores
**/
trigger ServiceTrigger on Service__c (after insert, after update) {
    ServiceTriggerHandler.run();
}