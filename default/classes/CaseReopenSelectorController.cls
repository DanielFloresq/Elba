/**
 * @description       : Apex controller for the caseReopenSelector LWC.
 *                      Provides picklist values, related Orders and Services
 *                      for the Case reopening flow and Order record page.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 20-04-2026
 * @last modified by  : Daniel Flores
 */
public with sharing class CaseReopenSelectorController {

    @TestVisible
    private static Boolean bypassApprovalInTests = false;

    // ────────────────────────────────────────────────────────────────
    // Wrapper classes
    // ────────────────────────────────────────────────────────────────

    /**
     * @description Wrapper for a picklist entry (label + value).
     */
    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    /**
     * @description Wrapper that groups an Order with its child Services.
     */
    public class OrderWithServices {
        @AuraEnabled public Order orderRecord;
        @AuraEnabled public List<Service__c> services;

        public OrderWithServices(Order orderRecord, List<Service__c> services) {
            this.orderRecord = orderRecord;
            this.services = services;
        }
    }

    /**
     * @description Wrapper returned when the approval request is submitted.
     */
    public class ApprovalSubmissionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String processInstanceId;
        @AuraEnabled public String message;

        public ApprovalSubmissionResult(Boolean success, String processInstanceId, String message) {
            this.success = success;
            this.processInstanceId = processInstanceId;
            this.message = message;
        }
    }

    // ────────────────────────────────────────────────────────────────
    // Public methods
    // ────────────────────────────────────────────────────────────────

    /**
     * @description Returns the picklist label/value pairs for Case.ReopeningReason__c.
     *              Always returns the **label** visible to the user, not the API name.
     * @return List<PicklistOption> with label and value for each active entry
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getReopeningReasons() {
        List<PicklistOption> options = new List<PicklistOption>();

        Schema.DescribeFieldResult fieldDescribe = Case.ReopeningReason__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }

        return options;
    }

    /**
     * @description Returns Orders linked to the given Case (via CaseNumber__c lookup)
     *              together with their child Service__c records.
     * @param caseId The Case record Id
     * @return List<OrderWithServices>
     */
    @AuraEnabled(cacheable=true)
    public static List<OrderWithServices> getOrdersWithServices(Id caseId) {
        if (caseId == null) {
            return new List<OrderWithServices>();
        }

        // Fetch Orders linked to this Case
        List<Order> orders = [
            SELECT Id, OrderNumber, Guild__c, ProviderType__c, Type
            FROM   Order
            WHERE  CaseNumber__c = :caseId AND Status = 'Order Completed'
            ORDER BY OrderNumber ASC
        ];

        for (Order orderRecord : orders) {
            applyOrderDisplayLabels(orderRecord);
        }

        if (orders.isEmpty()) {
            return new List<OrderWithServices>();
        }

        // Collect Order Ids
        Set<Id> orderIds = new Set<Id>();
        for (Order o : orders) {
            orderIds.add(o.Id);
        }

        // Fetch Services for all these Orders in a single query
        Map<Id, List<Service__c>> servicesByOrder = new Map<Id, List<Service__c>>();
        for (Service__c svc : [
            SELECT Id, Name, Type__c, Order__c,
                   Stakeholder__c, Stakeholder__r.Name
            FROM   Service__c
            WHERE  Order__c IN :orderIds AND Status__c = 'Executada/Terminada'
            ORDER BY Name ASC
        ]) {
            applyServiceDisplayLabels(svc);
            if (!servicesByOrder.containsKey(svc.Order__c)) {
                servicesByOrder.put(svc.Order__c, new List<Service__c>());
            }
            servicesByOrder.get(svc.Order__c).add(svc);
        }

        // Build wrappers
        List<OrderWithServices> result = new List<OrderWithServices>();
        for (Order o : orders) {
            List<Service__c> svcs = servicesByOrder.containsKey(o.Id)
                ? servicesByOrder.get(o.Id)
                : new List<Service__c>();
            result.add(new OrderWithServices(o, svcs));
        }

        return result;
    }

    /**
     * @description Returns Services related to a single Order.
     *              Used when the component is placed on an Order record page.
     * @param orderId The Order record Id
     * @return List<Service__c>
     */
    @AuraEnabled(cacheable=true)
    public static List<Service__c> getServicesForOrder(Id orderId) {
        if (orderId == null) {
            return new List<Service__c>();
        }

        List<Service__c> result = [
            SELECT Id, Name, Type__c,
                   Stakeholder__c, Stakeholder__r.Name
            FROM   Service__c
            WHERE  Order__c = :orderId AND Status__c = 'Executada/Terminada'
            ORDER BY Name ASC
        ];

        for (Service__c serviceRecord : result) {
            applyServiceDisplayLabels(serviceRecord);
        }

        return result;
    }

    /**
     * @description Persists the reopening reason and selected record Ids on the Case,
     *              and synchronizes the Selected_For_Reopening__c flags on Orders and Services.
     * @param caseId Current Case Id
     * @param reopeningReason Selected reopening reason value
     * @param selectedOrderIds Selected Order Ids
     * @param selectedServiceIds Selected Service Ids
     * @param availableOrderIds All Order Ids currently loaded in the component
     * @param availableServiceIds All Service Ids currently loaded in the component
     */
    @AuraEnabled
    public static void saveReopeningSelection(
        Id caseId,
        String reopeningReason,
        String reopeningDescription,
        List<Id> selectedOrderIds,
        List<Id> selectedServiceIds,
        List<Id> availableOrderIds,
        List<Id> availableServiceIds
    ) {
        if (caseId == null) {
            throw new AuraHandledException('Case Id is required.');
        }

        update new Case(
            Id = caseId,
            ReopeningReason__c = reopeningReason,
            ReopeningDescription__c = reopeningDescription,
            Selected_Order_Ids__c = JSON.serialize(selectedOrderIds == null ? new List<Id>() : selectedOrderIds),
            Selected_Service_Ids__c = JSON.serialize(selectedServiceIds == null ? new List<Id>() : selectedServiceIds)
        );

        syncSelectionFlagsInternal(
            availableOrderIds,
            selectedOrderIds,
            availableServiceIds,
            selectedServiceIds
        );
    }

    /**
     * @description Synchronizes the boolean visual indicators for selected Orders and Services.
     *              Selected records are marked with true and deselected loaded records with false.
     * @param availableOrderIds All Order Ids currently loaded in the component
     * @param selectedOrderIds Currently selected Order Ids
     * @param availableServiceIds All Service Ids currently loaded in the component
     * @param selectedServiceIds Currently selected Service Ids
     */
    @AuraEnabled
    public static void syncSelectionFlags(
        List<Id> availableOrderIds,
        List<Id> selectedOrderIds,
        List<Id> availableServiceIds,
        List<Id> selectedServiceIds
    ) {
        syncSelectionFlagsInternal(
            availableOrderIds,
            selectedOrderIds,
            availableServiceIds,
            selectedServiceIds
        );
    }

    /**
     * @description Submits the current Case to the approval process ClaimReopening.
     * @param caseId Current Case Id
     * @return Result wrapper with success and process instance Id
     */
    @AuraEnabled
    public static ApprovalSubmissionResult submitClaimReopeningApproval(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case Id is required to submit the approval process.');
        }

        if (Test.isRunningTest() && bypassApprovalInTests) {
            return new ApprovalSubmissionResult(true, String.valueOf(caseId), 'Approval submission bypassed in test context.');
        }

        Approval.ProcessSubmitRequest request = new Approval.ProcessSubmitRequest();
        request.setObjectId(caseId);
        request.setProcessDefinitionNameOrId('ClaimReopening');

        Approval.ProcessResult result = Approval.process(request);
        if (!result.isSuccess()) {
            throw new AuraHandledException('The approval process could not be submitted.');
        }

        return new ApprovalSubmissionResult(
            true,
            result.getInstanceId(),
            'Approval process submitted successfully.'
        );
    }

    /**
     * @description Directly reopens the current Order and the selected Services.
     *              Used on the Order record page where no approval process is required.
     * @param orderId Current Order Id
     * @param selectedServiceIds Selected Service Ids to reopen
     * @param availableServiceIds All Service Ids loaded in the component
     */
    @AuraEnabled
    public static void reopenOrderAndServices(
        Id orderId,
        List<Id> selectedServiceIds,
        List<Id> availableServiceIds
    ) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }

        Datetime reopeningDatetime = System.now();
        Order ord = [SELECT ID, Status FROM Order WHERE Id = :orderId LIMIT 1];
        if (ord.Status != 'Presupuestación' && ord.Status != 'Operational Closure') {
            update new Order(
                Id = orderId,
                Status = 'Avance'
            );
        }

        Set<Id> serviceIdsToSync = new Set<Id>(availableServiceIds == null ? new List<Id>() : availableServiceIds);
        Set<Id> selectedServiceIdSet = new Set<Id>(selectedServiceIds == null ? new List<Id>() : selectedServiceIds);

        if (serviceIdsToSync.isEmpty()) {
            return;
        }

        List<Service__c> servicesToUpdate = new List<Service__c>();
        for (Service__c serviceRecord : [
            SELECT Id, ReopeningApprovalStatus__c, ReopeningDate__c, Selected_For_Reopening__c
            FROM Service__c
            WHERE Id IN :serviceIdsToSync AND Status__c = 'Executada/Terminada'
        ]) {
            Boolean isSelected = selectedServiceIdSet.contains(serviceRecord.Id);
            
            if (isSelected) {
                serviceRecord.Status__c = 'En Execucion';
                serviceRecord.ReopeningDate__c = reopeningDatetime;
            }
            servicesToUpdate.add(serviceRecord);
        }

        if (!servicesToUpdate.isEmpty()) {
            update servicesToUpdate;
        }
    }

    private static void syncSelectionFlagsInternal(
        List<Id> availableOrderIds,
        List<Id> selectedOrderIds,
        List<Id> availableServiceIds,
        List<Id> selectedServiceIds
    ) {
        Set<Id> orderIdsToSync = new Set<Id>(availableOrderIds == null ? new List<Id>() : availableOrderIds);
        Set<Id> selectedOrderIdSet = new Set<Id>(selectedOrderIds == null ? new List<Id>() : selectedOrderIds);
        Set<Id> serviceIdsToSync = new Set<Id>(availableServiceIds == null ? new List<Id>() : availableServiceIds);
        Set<Id> selectedServiceIdSet = new Set<Id>(selectedServiceIds == null ? new List<Id>() : selectedServiceIds);

        List<Order> ordersToUpdate = new List<Order>();
        if (!orderIdsToSync.isEmpty()) {
            for (Order orderRecord : [
                SELECT Id, Selected_For_Reopening__c
                FROM Order
                WHERE Id IN :orderIdsToSync
            ]) {
                Boolean shouldBeSelected = selectedOrderIdSet.contains(orderRecord.Id);
                if (orderRecord.Selected_For_Reopening__c != shouldBeSelected) {
                    orderRecord.Selected_For_Reopening__c = shouldBeSelected;
                    ordersToUpdate.add(orderRecord);
                }
            }
        }

        List<Service__c> servicesToUpdate = new List<Service__c>();
        if (!serviceIdsToSync.isEmpty()) {
            for (Service__c serviceRecord : [
                SELECT Id, Selected_For_Reopening__c
                FROM Service__c
                WHERE Id IN :serviceIdsToSync
            ]) {
                Boolean shouldBeSelected = selectedServiceIdSet.contains(serviceRecord.Id);
                if (serviceRecord.Selected_For_Reopening__c != shouldBeSelected) {
                    serviceRecord.Selected_For_Reopening__c = shouldBeSelected;
                    servicesToUpdate.add(serviceRecord);
                }
            }
        }

        if (!ordersToUpdate.isEmpty()) {
            update ordersToUpdate;
        }

        if (!servicesToUpdate.isEmpty()) {
            update servicesToUpdate;
        }
    }

    private static String getPicklistLabel(Schema.SObjectField fieldToken, String apiValue) {
        if (String.isBlank(apiValue)) {
            return apiValue;
        }

        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.getValue() == apiValue) {
                return entry.getLabel();
            }
        }

        return apiValue;
    }

    private static String getMultiPicklistLabels(Schema.SObjectField fieldToken, String apiValues) {
        if (String.isBlank(apiValues)) {
            return apiValues;
        }

        Map<String, String> labelsByValue = new Map<String, String>();
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            labelsByValue.put(entry.getValue(), entry.getLabel());
        }

        List<String> labels = new List<String>();
        for (String valueItem : apiValues.split(';')) {
            String trimmedValue = valueItem != null ? valueItem.trim() : null;
            if (String.isBlank(trimmedValue)) {
                continue;
            }
            labels.add(labelsByValue.containsKey(trimmedValue) ? labelsByValue.get(trimmedValue) : trimmedValue);
        }

        return String.join(labels, '; ');
    }

    private static void applyOrderDisplayLabels(Order orderRecord) {
        if (orderRecord == null) {
            return;
        }

        orderRecord.put('Guild__c', getMultiPicklistLabels(Order.Guild__c, (String) orderRecord.get('Guild__c')));
        orderRecord.put('ProviderType__c', getPicklistLabel(Order.ProviderType__c, (String) orderRecord.get('ProviderType__c')));
        orderRecord.put('Type', getPicklistLabel(Order.Type, (String) orderRecord.get('Type')));
    }

    private static void applyServiceDisplayLabels(Service__c serviceRecord) {
        if (serviceRecord == null) {
            return;
        }

        serviceRecord.put('Type__c', getPicklistLabel(Service__c.Type__c, (String) serviceRecord.get('Type__c')));
    }
}