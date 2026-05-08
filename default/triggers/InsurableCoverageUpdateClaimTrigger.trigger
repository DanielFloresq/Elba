/**
 * @description       : 
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 05-03-2026
 * @last modified by  : Daniel Flores
**/
trigger InsurableCoverageUpdateClaimTrigger on InsurableCoverage__c (after insert, after update, after delete, after undelete) {
    PelayoInsurableCoverageTriggerHandler.run();
}