/**
 * @description       : MKIS-specific Order trigger logic.
 *                      Determines when to call MKIS ELBA API for Create/Update Service and Create Contact.
 * @author            : Daniel Flores
 * @group             : MKIS Integration
 * @last modified on  : 07-05-2026
 * @last modified by  : Daniel Flores
**/
public without sharing class MKISElbaOrderTriggerLogic {
    // Nome do utilizador de integração MKIS (display name, estável entre ambientes)
    private static final String MKIS_INTEGRATION_USER_NAME = 'MKIS Integration';

    /**
    * @description Processes Orders in the trigger context for MKIS integration.
    * @param newMap New Order records map
    * @param oldMap Old Order records map
    * @param isInsert Whether this is an insert operation
    * @param isUpdate Whether this is an update operation
    **/
    public static void processMKISOrder(
        Map<Id, Order> newMap,
        Map<Id, Order> oldMap,
        Boolean isInsert,
        Boolean isUpdate
    ) {
        if (newMap == null || newMap.isEmpty()) return;

        Map<Id, Account> accountsById = getAccountsById(newMap.values());

        List<Id> createServiceOrderIds = new List<Id>();
        List<Id> updateServiceOrderIds = new List<Id>();
        List<Id> createContactOrderIds = new List<Id>();

        for (Order newOrder : newMap.values()) {
            Boolean newAccountIsSupplier = isSupplierAccount(newOrder, accountsById);

            if (isInsert && newAccountIsSupplier) {
                
                createServiceOrderIds.add(newOrder.Id);
            }

            if (isUpdate) {
                Order oldOrder = oldMap != null ? oldMap.get(newOrder.Id) : null;
                Boolean accountChanged = oldOrder != null && newOrder.AccountId != oldOrder.AccountId;

                if (/* accountChanged && */ newAccountIsSupplier && newOrder.UrlLinkStatus__c != true) {
                    createServiceOrderIds.add(newOrder.Id);
                }

                // UPDATE SERVICE: Quando um encargo é atualizado
                if (newAccountIsSupplier && newOrder.UrlLinkStatus__c == true && hasRelevantServiceFieldsChanged(newOrder, oldOrder)) {
                    updateServiceOrderIds.add(newOrder.Id);
                }

                // CREATE CONTACT: Quando certos campos são atualizados
                // Não chamar endpoint de contacts se o utilizador for MKIS Integration
                if (UserInfo.getName() != MKIS_INTEGRATION_USER_NAME) {
                    if (MKISElbaContactHandler.hasContactFieldsChanged(newOrder, oldOrder)) {
                        createContactOrderIds.add(newOrder.Id);
                    }
                }
            }
        }
        System.debug('Quantos encargos estão aqui:' + createServiceOrderIds.size());
        if (!createServiceOrderIds.isEmpty() && !System.isFuture() && !System.isBatch()) {

            System.debug('Entrei aqui para depurar');
            List<Id> validCreateServiceOrderIds = CreateNewServiceController.filterOrdersWithMandatoryFields(createServiceOrderIds);
            if (!validCreateServiceOrderIds.isEmpty()) {
                System.debug('Entrei aqui para depurar 2');
                if (UserInfo.getName() != MKIS_INTEGRATION_USER_NAME) {
                    MKISElbaServiceHandler.createServiceAsync(validCreateServiceOrderIds);
                }
            }
        }

        if (!updateServiceOrderIds.isEmpty() && !System.isFuture() && !System.isBatch()) {
            if (UserInfo.getName() != MKIS_INTEGRATION_USER_NAME) {
                MKISElbaServiceHandler.updateServiceAsync(updateServiceOrderIds);
            }
            
        }

        if (!createContactOrderIds.isEmpty() && !System.isFuture() && !System.isBatch()) {
            if (UserInfo.getName() != MKIS_INTEGRATION_USER_NAME) {
                MKISElbaContactHandler.createContactAsync(createContactOrderIds);
            }
        }
    }

    /**
    * @description Checks if any service-relevant fields have changed between old and new Order.
    * @param newOrder The new Order record
    * @param oldOrder The old Order record
    * @return Boolean true if relevant fields changed
    **/
    private static Boolean hasRelevantServiceFieldsChanged(Order newOrder, Order oldOrder) {
        if (oldOrder == null) {
            return false;
        }

        return newOrder.AccountId != oldOrder.AccountId
            || newOrder.BillToContactId != oldOrder.BillToContactId
            || newOrder.CaseNumber__c != oldOrder.CaseNumber__c
            || newOrder.RelatedOrder__c != oldOrder.RelatedOrder__c
            // Policy / insured
            || newOrder.Urgent__c != oldOrder.Urgent__c
            // Contact
            // (driven by BillToContactId above)
            // Dates
            // (driven by CaseNumber__c above)
            // Optional details
            || newOrder.Observaciones__c != oldOrder.Observaciones__c
            || newOrder.Reason__c != oldOrder.Reason__c
            || newOrder.SubReason__c != oldOrder.SubReason__c
            || newOrder.Guild__c != oldOrder.Guild__c
            || newOrder.Coverage__c != oldOrder.Coverage__c
            // Integer flags
            || newOrder.OPFVTSIndicatorsPresent__c != oldOrder.OPFVTSIndicatorsPresent__c
            // Visit fields
            || newOrder.VisitCompleted__c != oldOrder.VisitCompleted__c
            || newOrder.VisitNotCompletedReason__c != oldOrder.VisitNotCompletedReason__c
            || newOrder.VisitDateTime__c != oldOrder.VisitDateTime__c
            || newOrder.VisitType__c != oldOrder.VisitType__c
            || newOrder.OperatorDescription__c != oldOrder.OperatorDescription__c
            // Damage assessment flags
            || newOrder.OriginIdentification__c != oldOrder.OriginIdentification__c
            || newOrder.DamagePriortoPolicyInception__c != oldOrder.DamagePriortoPolicyInception__c
            || newOrder.DamagePriortoDateofOccurrence__c != oldOrder.DamagePriortoDateofOccurrence__c
            || newOrder.OngoingDamage__c != oldOrder.OngoingDamage__c
            || newOrder.DamageDuetoLackofMaintenance__c != oldOrder.DamageDuetoLackofMaintenance__c
            || newOrder.ClaimCoverage__c != oldOrder.ClaimCoverage__c
            || newOrder.Rejection__c != oldOrder.Rejection__c
            || newOrder.OperatorAssessment__c != oldOrder.OperatorAssessment__c
            || newOrder.MeetsVATConditions__c != oldOrder.MeetsVATConditions__c
            || newOrder.InitialDamagesLocated__c != oldOrder.InitialDamagesLocated__c
            || newOrder.InitialDamagesRepaired__c != oldOrder.InitialDamagesRepaired__c
            || newOrder.NoRepairReason__c != oldOrder.NoRepairReason__c
            || newOrder.AdjusterInterventionRequired__c != oldOrder.AdjusterInterventionRequired__c
            || newOrder.ReasonforAdjusterIntervention__c != oldOrder.ReasonforAdjusterIntervention__c
            // Budget / totals
            || newOrder.TotalBudgetAmount__c != oldOrder.TotalBudgetAmount__c;
    }

    /**
    * @description Queries Accounts related to the given Orders and returns them in a map by Id.
    * @param orders List of Order records
    * @return Map of Account Id to Account record
    **/
    private static Map<Id, Account> getAccountsById(List<Order> orders) {
        Set<Id> accountIds = new Set<Id>();
        for (Order ord : orders) {
            if (ord.AccountId != null) {
                accountIds.add(ord.AccountId);
            }
        }

        if (accountIds.isEmpty()) {
            return new Map<Id, Account>();
        }

        return new Map<Id, Account>([
            SELECT Id, RecordType.DeveloperName
            FROM Account
            WHERE Id IN :accountIds
        ]);
    }

    /**
    * @description Determines whether the Account associated with the Order has a Supplier record type.
    * @param ord The Order record
    * @param accountsById Map of Account Id to Account record
    * @return Boolean true if the related Account is a Supplier
    **/
    private static Boolean isSupplierAccount(Order ord, Map<Id, Account> accountsById) {
        if (ord == null || ord.AccountId == null || accountsById == null) {
            return false;
        }

        Account relatedAccount = accountsById.get(ord.AccountId);
        return relatedAccount != null && relatedAccount.RecordType != null && relatedAccount.RecordType.DeveloperName == 'Supplier';
    }
}