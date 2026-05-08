/**
 * @description       : Business logic for Service trigger handling Pelayo integration operations
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 10-04-2026
 * @last modified by  : Daniel Flores
**/
public without sharing class ServiceLogic {

    private static final String PELAYO_ACCOUNT_CODE = 'PLYO';
    private static final String serviceStatusOpen = 'Aberto';
    private static final String statusAdministrativeClosure = 'Executada/Terminada';
    private static final String serviceStatusVisit = 'Visit';
    private static final String serviceEstimate = 'Estimate';
    private static final String serviceStatusCancelled = 'Cancelled'; 
    private static final String recordTypeMultiguild = 'Multiguild';
    private static final String typeAN = 'AN';//Feito
    private static final String typeAL = 'AL';//Feito
    private static final String typePR = 'PR';//Feito
    private static final String typeMO = 'MO'; // Else
    private static final String typeCE = 'CE';//Feito

    @TestVisible
    private static Boolean bypassExternalActions = false;

    /**
     * @description Entry point for processing service records after trigger execution, queries scoped services and delegates to processScopedServices
     * @param newMap Map of new Service__c records by ID from trigger context
     * @param oldMap Map of old Service__c records by ID from trigger context
     */
    public static void process(
        Map<Id, Service__c> newMap,
        Map<Id, Service__c> oldMap
    ) {
        if (newMap == null || newMap.isEmpty()) {
            return;
        }

        List<Service__c> scopedServices = [
            SELECT Id, Order__c, Status__c, RecordType.Name
            FROM Service__c
            WHERE Id IN :newMap.keySet()
        ];

        processScopedServices(scopedServices, oldMap);
    }

    /**
     * @description Processes scoped service records, categorizing them by Pelayo encargo action type and invoking the appropriate external calls
     * @param scopedServices List of Service__c records with Order and RecordType fields queried
     * @param oldMap Map of old Service__c records by ID for change detection
     */
    @TestVisible
    private static void processScopedServices(
        List<Service__c> scopedServices,
        Map<Id, Service__c> oldMap
    ) {
        if (scopedServices == null || scopedServices.isEmpty()) {
            return;
        }

        Set<Id> orderIds = new Set<Id>();
        for (Service__c currentService : scopedServices) {
            if (currentService.Order__c != null) {
                orderIds.add(currentService.Order__c);
            }
        }

        if (orderIds.isEmpty()) {
            return;
        }

        Map<Id, Order> ordersById = new Map<Id, Order>([
            SELECT Id, Status, CaseNumber__r.GrandAccount__c
            FROM Order
            WHERE Id IN :orderIds
        ]);

        Set<String> orderIdstypeAN = new Set<String>();
        Set<String> orderIdstypeAL = new Set<String>();
        Set<String> orderIdstypePR = new Set<String>();
        Set<String> orderIdstypeMO = new Set<String>();
        Set<String> orderIdstypeCE = new Set<String>();

        for (Service__c currentService : scopedServices) {
            if (currentService.Order__c == null) {
                continue;
            }
            Service__c oldService = oldMap != null ? oldMap.get(currentService.Id) : null;
            Order relatedOrder = ordersById.get(currentService.Order__c);
            if (relatedOrder == null || relatedOrder.CaseNumber__r == null) {
                continue;
            }

            if (relatedOrder.CaseNumber__r.GrandAccount__c != PELAYO_ACCOUNT_CODE) {
                continue;
            }

            if (currentService.RecordType == null
                || currentService.RecordType.Name != RecordTypeMultiguild) {
                continue;
            }

            if (Trigger.isExecuting && Trigger.isInsert) {
                orderIdstypeAL.add((String) relatedOrder.Id); // QUANDO É CRIADO
                continue;
            }

            
            

            if (oldService != null && oldService.Status__c !=  currentService.Status__c && currentService.Status__c == serviceEstimate ) { 
                orderIdstypePR.add((String) relatedOrder.Id);//ESTIMATE
                continue;
            }

            if (oldService != null && oldService.Status__c !=  currentService.Status__c && currentService.Status__c == statusAdministrativeClosure ) { 
                orderIdstypeCE.add((String) relatedOrder.Id);//Closure
                continue;
            }

            if (oldService != null && oldService.Status__c !=  currentService.Status__c && currentService.Status__c == serviceStatusCancelled ) { 
                orderIdstypeAN.add((String) relatedOrder.Id);//Cancelled
                continue;
            }


            orderIdstypeMO.add((String) relatedOrder.Id);//ELSE

        }
        invokePutPelayoEncargoAction(new List<String>(orderIdstypeAN), typeAN);
        invokePutPelayoEncargoAction(new List<String>(orderIdstypeAL), typeAL);
        invokePutPelayoEncargoAction(new List<String>(orderIdstypePR), typePR);
        invokePutPelayoEncargoAction(new List<String>(orderIdstypeMO), typeMO);
        invokePutPelayoEncargoAction(new List<String>(orderIdstypeCE), typeCE);


    }

    /**
     * @description Invokes the Pelayo encargo web service for a list of order IDs with the specified action type
     * @param orderIds List of Order ID strings to send to the Pelayo service
     * @param type The encargo action type code (AN, AL, PR, MO, CE)
     */
    private static void invokePutPelayoEncargoAction(List<String> orderIds, String type) {
        if (bypassExternalActions || orderIds == null || orderIds.isEmpty()) {
            return;
        }

        PelayoWebServiceController.sendEncargoPelayoService(orderIds, type, System.isFuture());
    }
}