/**
 * @description       : Business logic for Order trigger handling Pelayo integration operations
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 22-04-2026
 * @last modified by  : Daniel Flores
**/
public without sharing class OrderTriggerLogic {

    private static final String PELAYO_ACCOUNT_CODE = 'PLYO';
    private static final String STATUS_OPEN = 'Open';
    private static final String STATUS_ORDER_ASSIGNMENT = 'Order Assignment';
    private static final String STATUS_CIERRE = 'Order Completed';
    private static final String STATUS_ANULACION = 'Order Cancelled';

    private static final String TYPE_CREATION = 'AL';
    private static final String TYPE_ASSIGNACION = 'AS';
    private static final String TYPE_REASSIGNACION = 'RS';
    private static final String TYPE_AVANCE = 'AV';
    private static final String TYPE_CIERRE = 'CE';
    private static final String TYPE_ANULACION = 'AN';
    private static final String TYPE_MODIFICATION = 'MO';

    private static final String SUPPLIER_ACCOUNT = 'Supplier';
    private static final String PELAYO_INTEGRATION_USER_NAME = 'Pelayo Integration';

    public static Boolean bypassExternalActions = false;

    @TestVisible
    static Boolean treatCurrentUserAsIntegrationUser;

    @TestVisible
    static String lastInvokedType;

    @TestVisible
    static List<String> lastInvokedOrderIds;

    @TestVisible
    static List<String> invokedTypesHistory;

    private static Boolean cachedIsIntegrationUser;
    private static Set<Id> createdOrderIdsInCurrentTransaction;

    /**
    * @description Process the orders in the trigger context and determine which ones require actions to be sent to Pelayo.
    * @author Afonso Duque | 26-02-2026
    * @param  newMap
    * @param  oldMap
    * @param  isInsert
    * @param  isUpdate
    **/
    public static void processPelayoOrder(
        Map<Id, Order> newMap,
        Map<Id, Order> oldMap,
        Boolean isInsert,
        Boolean isUpdate
    ) {
        if (!newMap.isEmpty()) {
            List<Order> scopedOrders = [
                SELECT Id, AccountId, Status, ChargeIdentifier__c, CaseNumber__r.GrandAccount__c, AccountTypeRelated__c, TotalAmount, Guild__c, EndDate, CreatedDate, OwnerId
                FROM Order
                WHERE Id IN :newMap.keySet()
                AND CaseNumber__r.GrandAccount__c =:PELAYO_ACCOUNT_CODE
            ];
            processScopedOrders(scopedOrders, oldMap, isInsert, isUpdate);
        }
    }

    /**
    * @description Process the orders that are relevant for Pelayo and determine which action to take based on their status and whether they have an external identifier.
    * @author Afonso Duque | 26-02-2026
    * @param  scopedOrders
    * @param  oldMap
    * @param  isInsert
    * @param  isUpdate
    **/
    @TestVisible
    private static void processScopedOrders(
        List<Order> scopedOrders,
        Map<Id, Order> oldMap,
        Boolean isInsert,
        Boolean isUpdate
    ) {
        if (!scopedOrders.isEmpty()) {

            List<String> createOrderIds = new List<String>();
            List<String> assignationOrderIds = new List<String>();
            List<String> reassignmentOrderIds = new List<String>();
            List<String> cierreOrderIds = new List<String>();
            List<String> anulacionOrderIds = new List<String>();
            List<String> avanceOrderIds = new List<String>();
            List<String> modificationOrderIds = new List<String>();

            for (Order currentOrder : scopedOrders) {
                Order oldOrder = (oldMap != null ? oldMap.get(currentOrder.Id) : null);

                Boolean hasExternalIdentifier = (currentOrder.ChargeIdentifier__c != null);

                if(isInsert){
                    if (shouldSendCreation(currentOrder, hasExternalIdentifier)) {
                        createOrderIds.add((String) currentOrder.Id);
                    }
                }

                if (isUpdate && shouldSendAssignationForIntegrationUser(oldOrder, currentOrder, hasExternalIdentifier)) {
                    assignationOrderIds.add((String) currentOrder.Id);
                    continue;
                }

                if (isUpdate && shouldSendAssignationAfterCreationInSameTransaction(oldOrder, currentOrder, hasExternalIdentifier)) {
                    assignationOrderIds.add((String) currentOrder.Id);
                    continue;
                }

                if (isUpdate && hasExternalIdentifier) {
                    if (!hasRelevantPelayoChanges(oldOrder, currentOrder)) {
                        continue;
                    }
                    Boolean isStatusChanged = (oldOrder != null && oldOrder.Status != currentOrder.Status);
                    Boolean isAccountChanged = (oldOrder != null && oldOrder.AccountId != currentOrder.AccountId);
                    Boolean isAccountTypeRelatedChanged = (oldOrder != null && oldOrder.AccountTypeRelated__c != currentOrder.AccountTypeRelated__c);

                    if(isAccountTypeRelatedChanged && isAccountChanged && currentOrder.AccountTypeRelated__c == SUPPLIER_ACCOUNT) {
                        assignationOrderIds.add((String) currentOrder.Id);
                    } else if(!isAccountTypeRelatedChanged && isAccountChanged && currentOrder.AccountTypeRelated__c == SUPPLIER_ACCOUNT){
                        reassignmentOrderIds.add((String) currentOrder.Id);
                    } else if (isStatusChanged && currentOrder.Status == STATUS_CIERRE) {
                        cierreOrderIds.add((String) currentOrder.Id);
                    } else if (isStatusChanged && currentOrder.Status == STATUS_ANULACION) {
                        anulacionOrderIds.add((String) currentOrder.Id);
                    } else if (isAvanceFieldsChanged(oldOrder, currentOrder)) {
                        avanceOrderIds.add((String) currentOrder.Id);
                    } else {
                        modificationOrderIds.add((String) currentOrder.Id);
                    }

                }
            }

            system.debug(createOrderIds);
            system.debug(assignationOrderIds);
            system.debug(reassignmentOrderIds);
            system.debug(cierreOrderIds);
            system.debug(anulacionOrderIds);
            system.debug(avanceOrderIds);
            system.debug(modificationOrderIds);

            invokePutPelayoEncargoAction(createOrderIds, TYPE_CREATION);
            invokePutPelayoEncargoAction(assignationOrderIds, TYPE_ASSIGNACION);
            invokePutPelayoEncargoAction(reassignmentOrderIds, TYPE_REASSIGNACION);
            invokePutPelayoEncargoAction(cierreOrderIds, TYPE_CIERRE);
            invokePutPelayoEncargoAction(anulacionOrderIds, TYPE_ANULACION);
            invokePutPelayoEncargoAction(avanceOrderIds, TYPE_AVANCE);
            invokePutPelayoEncargoAction(modificationOrderIds, TYPE_MODIFICATION);
        }
    }

    @TestVisible
    private static Boolean shouldSendCreation(
        Order currentOrder,
        Boolean hasExternalIdentifier
    ) {
        return currentOrder != null && !hasExternalIdentifier ;
    }

    @TestVisible
    private static Boolean shouldSendAssignationForIntegrationUser(
        Order oldOrder,
        Order currentOrder,
        Boolean hasExternalIdentifier
    ) {
        return oldOrder != null
            && currentOrder != null
            && hasExternalIdentifier
            && isIntegrationUser()
            && oldOrder.AccountId != currentOrder.AccountId
            && currentOrder.AccountTypeRelated__c == SUPPLIER_ACCOUNT;
    }

    @TestVisible
    private static Boolean shouldSendAssignationAfterCreationInSameTransaction(
        Order oldOrder,
        Order currentOrder,
        Boolean hasExternalIdentifier
    ) {
        return oldOrder != null
            && currentOrder != null
            && !hasExternalIdentifier
            && wasCreatedInCurrentTransaction(currentOrder.Id)
            && oldOrder.AccountId != currentOrder.AccountId
            && currentOrder.AccountTypeRelated__c == SUPPLIER_ACCOUNT;
    }

    /**
    * @description Checks whether any avance-related fields have changed between the old and new Order.
    * @param oldOrder The previous version of the Order record
    * @param newOrder The current version of the Order record
    * @return Boolean True if any avance field has changed
    **/
    public static Boolean isAvanceFieldsChanged(Order oldOrder, Order newOrder) {
        return (/* oldOrder.Status != newOrder.Status
            || oldOrder.Guild__c != newOrder.Guild__c
            || oldOrder.TotalAmount != newOrder.TotalAmount
            || oldOrder.OwnerId != newOrder.OwnerId
            || oldOrder.EndDate != newOrder.EndDate */ false);
    }   

    /**
    * @description Determines if any Pelayo-relevant fields have changed between the old and new Order.
    * @param oldOrder The previous version of the Order record
    * @param newOrder The current version of the Order record
    * @return Boolean True if any relevant field has changed
    **/
    private static Boolean hasRelevantPelayoChanges(Order oldOrder, Order newOrder) {
        if (oldOrder == null) {
            return true;
        }

        return oldOrder.Status != newOrder.Status
            || oldOrder.AccountId != newOrder.AccountId
            || oldOrder.AccountTypeRelated__c != newOrder.AccountTypeRelated__c
            || oldOrder.TotalAmount != newOrder.TotalAmount
            || oldOrder.Guild__c != newOrder.Guild__c
            || oldOrder.EndDate != newOrder.EndDate
            || oldOrder.OwnerId != newOrder.OwnerId
            || oldOrder.ChargeIdentifier__c != newOrder.ChargeIdentifier__c;
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

    private static Boolean wasCreatedInCurrentTransaction(Id orderId) {
        return orderId != null
            && createdOrderIdsInCurrentTransaction != null
            && createdOrderIdsInCurrentTransaction.contains(orderId);
    }

    private static void rememberCreatedOrders(List<String> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) {
            return;
        }

        if (createdOrderIdsInCurrentTransaction == null) {
            createdOrderIdsInCurrentTransaction = new Set<Id>();
        }

        for (String orderId : orderIds) {
            if (String.isNotBlank(orderId)) {
                createdOrderIdsInCurrentTransaction.add((Id) orderId);
            }
        }
    }

    /**
    * @description Invokes the Pelayo encargo web service action for the given Order Ids and type.
    * @param orderIds List of Order Id strings to process
    * @param type The Pelayo action type code (e.g. AL, AS, RS, AV, CE, AN, MO)
    **/
    private static void invokePutPelayoEncargoAction(List<String> orderIds, String type) {
        if (type == TYPE_CREATION) {
            rememberCreatedOrders(orderIds);
        }

        if (!orderIds.isEmpty() && Test.isRunningTest()) {
            lastInvokedType = type;
            lastInvokedOrderIds = new List<String>(orderIds);
            if (invokedTypesHistory == null) {
                invokedTypesHistory = new List<String>();
            }
            invokedTypesHistory.add(type);
        }

        if (!bypassExternalActions && !orderIds.isEmpty()) {
            PelayoWebServiceController.sendEncargoPelayoService(orderIds, type, System.isFuture());
        }
    }
}