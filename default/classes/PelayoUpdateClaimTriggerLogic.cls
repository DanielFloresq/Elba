/**
 * @description       : Determines when to invoke Pelayo updateClaim based on changes.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 18-03-2026
 * @last modified by  : Daniel Flores
**/
public without sharing class PelayoUpdateClaimTriggerLogic {

    @TestVisible
    public static Boolean bypassExternalActions = false;
    public static Boolean enableCalloutsInTests = false;

    private static final String PELAYO_ACCOUNT_CODE = 'PLYO';
    private static final String PELAYO_INTEGRATION_USER_NAME = 'Pelayo Integration';

    @TestVisible
    static Boolean treatCurrentUserAsIntegrationUser;

    private static Boolean cachedIsIntegrationUser;

    /**
     * @description Evaluates Case records from trigger context, identifies Pelayo cases with relevant field changes, and enqueues updateClaim callouts for affected Case Ids.
     * @param newMap Map of new Case records from Trigger.newMap
     * @param oldMap Map of old Case records from Trigger.oldMap (null on insert)
     * @param isInsert Whether the trigger operation is an insert
     * @param isUpdate Whether the trigger operation is an update
     **/
    public static void processCases(Map<Id, Case> newMap, Map<Id, Case> oldMap, Boolean isInsert, Boolean isUpdate) {
        if (bypassExternalActions || newMap == null || newMap.isEmpty()) {
            return;
        }

        Set<Id> caseIdsToSend = new Set<Id>();
        for (Case cNew : newMap.values()) {
            if (cNew == null) continue;
            if (cNew.GrandAccount__c != PELAYO_ACCOUNT_CODE) continue;

            if (isInsert) {
                caseIdsToSend.add(cNew.Id);
                continue;
            }

            Case cOld = oldMap != null ? oldMap.get(cNew.Id) : null;
            if (cOld == null) {
                caseIdsToSend.add(cNew.Id);
                continue;
            }

            if (isRelevantCaseChange(cOld, cNew)) {
                caseIdsToSend.add(cNew.Id);
            }
        }

        if (!caseIdsToSend.isEmpty()) {
            if (!System.isFuture() && !System.isQueueable() && !System.isBatch()) {
                PelayoUpdateClaimService.enqueue(caseIdsToSend);
            }
        }
    }

    /**
     * @description Enqueues Pelayo updateClaim callouts for a given set of Case Ids, typically invoked from related-object triggers (e.g. InsurableCoverage__c).
     * @param caseIds Set of Case Ids to process
     **/
    public static void processCaseIds(Set<Id> caseIds) {
        if (bypassExternalActions || caseIds == null || caseIds.isEmpty() || !shouldRunRelatedObjectCallouts()) {
            return;
        }
        if (System.isFuture() || System.isQueueable() || System.isBatch()) {
            return;
        }
        PelayoUpdateClaimService.enqueue(caseIds);
    }

    private static Boolean shouldRunRelatedObjectCallouts() {
        return !isIntegrationUser();
    }

    private static Boolean isIntegrationUser() {
        if (treatCurrentUserAsIntegrationUser != null) {
            return treatCurrentUserAsIntegrationUser;
        }

        if (cachedIsIntegrationUser != null) {
            return cachedIsIntegrationUser;
        }

        String currentUserName;
        try {
            currentUserName = [SELECT Name FROM User WHERE Id = :UserInfo.getUserId()].Name;
        } catch (Exception e) {
            currentUserName = null;
        }

        cachedIsIntegrationUser = (currentUserName == PELAYO_INTEGRATION_USER_NAME);
        return cachedIsIntegrationUser;
    }

    /**
     * @description Determines whether a Case update contains changes to fields that are relevant to the Pelayo updateClaim integration.
     * @param oldC Previous version of the Case record
     * @param newC Updated version of the Case record
     * @return Boolean True if at least one monitored field has changed
     **/
    @TestVisible
    static Boolean isRelevantCaseChange(Case oldC, Case newC) {
        return oldC.Subject != newC.Subject ||
            oldC.InsurerClaimReference__c != newC.InsurerClaimReference__c ||
            oldC.ExponentialQuadrant__c != newC.ExponentialQuadrant__c ||
            oldC.ClaimantDescription__c != newC.ClaimantDescription__c ||
            oldC.ClaimantName__c != newC.ClaimantName__c ||
            oldC.QuestionnaireComments__c != newC.QuestionnaireComments__c ||
            oldC.IncidentDate__c != newC.IncidentDate__c ||
            oldC.ClaimDate__c != newC.ClaimDate__c ||
            oldC.Reason__c != newC.Reason__c ||
            oldC.SubReason__c != newC.SubReason__c ||
            oldC.ClaimTypeIdentifier__c != newC.ClaimTypeIdentifier__c ||
            oldC.SituationType__c != newC.SituationType__c ||
            oldC.Urgent__c != newC.Urgent__c ||
            oldC.VitalOrganAffected__c != newC.VitalOrganAffected__c ||
            oldC.AssistanceService__c != newC.AssistanceService__c ||
            oldC.CurrentProvisionAmount__c != newC.CurrentProvisionAmount__c ||
            oldC.Deductible__c != newC.Deductible__c ||
            oldC.DeductibleUsed__c != newC.DeductibleUsed__c ||
            oldC.DamagesIncurred__c != newC.DamagesIncurred__c ||
            oldC.Marcadores__c != newC.Marcadores__c ||
            oldC.WantsSMSNotifications__c != newC.WantsSMSNotifications__c ||
            oldC.WantsEmailNotifications__c != newC.WantsEmailNotifications__c ||
            oldC.WantsWhatsAppNotifications__c != newC.WantsWhatsAppNotifications__c ||
            oldC.ClaimsHandlerName__c != newC.ClaimsHandlerName__c ||
            oldC.ClaimsHandlerEmail__c != newC.ClaimsHandlerEmail__c ||
            oldC.ContactId != newC.ContactId;
    }
}