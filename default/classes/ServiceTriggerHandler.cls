/**
 * @description       : Trigger handler for Service__c records delegating to ServiceLogic
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 24-02-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class ServiceTriggerHandler {

    private static Boolean isRunning = false;

    /**
     * @description Executes the Service__c after-update trigger logic with reentrance guard, delegating processing to ServiceLogic
     */
    public static void run() {
        if (isRunning) {
            return;
        }

        isRunning = true;
        try {
            if (Trigger.isAfter && Trigger.isInsert) {
                List<Id> insertedIds = new List<Id>(Trigger.newMap.keySet());
                if (!System.isFuture() && !System.isBatch()) {
                    MKISElbaInterventionHandler.createInterventionAsync(insertedIds);
                }
            }

            if (Trigger.isAfter && Trigger.isUpdate) {
                ServiceLogic.process(
                    (Map<Id, Service__c>) Trigger.newMap,
                    (Map<Id, Service__c>) Trigger.oldMap
                );

                List<Id> updatedIds = new List<Id>();
                for (Service__c svc : (List<Service__c>) Trigger.new) {
                    if (String.isNotBlank(svc.MKISId__c)) {
                        updatedIds.add(svc.Id);
                    }
                }
                if (!updatedIds.isEmpty() && !System.isFuture() && !System.isBatch()) {
                    MKISElbaInterventionHandler.updateInterventionAsync(updatedIds);
                }
            }
        } finally {
            isRunning = false;
        }
    }
}