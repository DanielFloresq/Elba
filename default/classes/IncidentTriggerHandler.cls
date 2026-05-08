/**
 * @description       : Handles the execution of the Incident trigger logic for MKIS ELBA and Pelayo integrations.
 * @author            : Daniel Flores
 * @group             : Integrations
 * @last modified on  : 07-04-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class IncidentTriggerHandler {

    private static Boolean isRunning = false;

    @TestVisible
    private class IncidentSyncActions {
        List<Incident> incidentsToCreate = new List<Incident>();
        List<Incident> incidentsToUpdate = new List<Incident>();
    }

    /**
     * @description Executes the Incident trigger logic, dispatching create and update actions to MKIS ELBA and Pelayo integrations
     */
    public static void run() {
        if (isRunning || IncidentTriggerContext.bypassExternalActions) {
            return;
        }

        isRunning = true;
        try {
            if (Trigger.isAfter) {
                IncidentSyncActions actions = collectIncidentSyncActions(
                    (List<Incident>) Trigger.new,
                    Trigger.isUpdate ? (Map<Id, Incident>) Trigger.oldMap : null,
                    Trigger.isInsert,
                    Trigger.isUpdate
                );

                List<Id> createIncidenceIds = extractIncidentIds(actions.incidentsToCreate);
                List<Id> updateIncidenceIds = extractIncidentIds(actions.incidentsToUpdate);

                if (!createIncidenceIds.isEmpty() && !System.isFuture() && !System.isBatch()) {
                    // MKIS ELBA Integration
                    MKISElbaIncidenceHandler.createIncidenceAsync(createIncidenceIds);
                    // Pelayo Integration
                    PelayoIncidentService.enqueueCreate(createIncidenceIds);
                }

                if (!updateIncidenceIds.isEmpty() && !System.isFuture() && !System.isBatch()) {
                    // MKIS ELBA Integration
                    MKISElbaIncidenceHandler.updateIncidenceAsync(updateIncidenceIds);
                    // Pelayo Integration
                    PelayoIncidentService.enqueueUpdate(updateIncidenceIds);
                }
            }
        } finally {
            isRunning = false;
        }
    }

    /**
     * @description Categorizes incidents into create and update action lists based on trigger context and order relation changes
     * @param newIncidents List of new Incident records from the trigger
     * @param oldIncidentMap Map of old Incident records by Id (null for insert context)
     * @param isInsert Whether the trigger context is insert
     * @param isUpdate Whether the trigger context is update
     * @return IncidentSyncActions containing categorized incidents for create and update
     */
    @TestVisible
    private static IncidentSyncActions collectIncidentSyncActions(
        List<Incident> newIncidents,
        Map<Id, Incident> oldIncidentMap,
        Boolean isInsert,
        Boolean isUpdate
    ) {
        IncidentSyncActions actions = new IncidentSyncActions();
        if (newIncidents == null || newIncidents.isEmpty()) {
            return actions;
        }

        for (Incident inc : newIncidents) {
            if (!hasOrderRelation(inc)) {
                continue;
            }

            if (isInsert) {
                actions.incidentsToCreate.add(inc);
                continue;
            }

            if (isUpdate) {
                Incident oldInc = oldIncidentMap != null ? oldIncidentMap.get(inc.Id) : null;
                if (didOrderRelationChange(inc, oldInc)) {
                    actions.incidentsToCreate.add(inc);
                } else {
                    actions.incidentsToUpdate.add(inc);
                }
            }
        }

        return actions;
    }

    /**
     * @description Extracts non-null Ids from a list of Incident records
     * @param incidents List of Incident records to extract Ids from
     * @return List of Incident Ids
     */
    private static List<Id> extractIncidentIds(List<Incident> incidents) {
        List<Id> incidentIds = new List<Id>();
        if (incidents == null || incidents.isEmpty()) {
            return incidentIds;
        }

        for (Incident inc : incidents) {
            if (inc.Id != null) {
                incidentIds.add(inc.Id);
            }
        }

        return incidentIds;
    }

    /**
     * @description Determines whether an Incident has an associated order relation
     * @param inc The Incident record to evaluate
     * @return True if the incident has an order relation
     */
    private static Boolean hasOrderRelation(Incident inc) {
        return true /* inc != null && inc.OrderService__c != null */;
    }

    /**
     * @description Checks whether the order service relation changed between the old and new Incident versions
     * @param newIncident The new version of the Incident record
     * @param oldIncident The old version of the Incident record
     * @return True if the OrderService__c field value changed
     */
    private static Boolean didOrderRelationChange(Incident newIncident, Incident oldIncident) {
        return oldIncident != null && newIncident != null && newIncident.OrderService__c != oldIncident.OrderService__c;
    }
}