/**
 * @description       : Trigger on Solicitation__c for Pelayo integration.
 * @author            : Daniel Flores
 * @group             : Pelayo Integration
 * @last modified on  : 07-04-2026
 * @last modified by  : Daniel Flores
**/
trigger SolicitationTrigger on Solicitation__c (after insert) {
    SolicitationTriggerHandler.run();
}