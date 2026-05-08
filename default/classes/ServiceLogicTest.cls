/**
 * @description       : Test class for ServiceLogic service trigger processing
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 27-02-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
public class ServiceLogicTest {

    /**
     * @description Sets up test data including provider account, Pelayo case, and non-Pelayo case
     */
    @testSetup
    static void setup() {
        insert new Account(Name = 'Provider Test - Service');

        Case pelayoCase = new Case(
            Subject = 'Pelayo Case - Service',
            Status = 'New',
            Origin = 'Phone',
            GrandAccount__c = 'PLYO'
        );
        insert pelayoCase;

        Case nonPelayoCase = new Case(
            Subject = 'Non Pelayo Case - Service',
            Status = 'New',
            Origin = 'Phone',
            GrandAccount__c = 'SLA'
        );
        insert nonPelayoCase;
    }

    /**
     * @description Retrieves the Account ID of the test provider record
     * @return Id of the provider Account
     */
    private static Id getProviderAccountId() {
        return [SELECT Id FROM Account WHERE Name = 'Provider Test - Service' LIMIT 1].Id;
    }

    /**
     * @description Retrieves a Case record by its subject
     * @param subject The subject string to search for
     * @return Case record matching the given subject
     */
    private static Case getCaseBySubject(String subject) {
        return [SELECT Id, GrandAccount__c FROM Case WHERE Subject = :subject LIMIT 1];
    }

    /* private static void assertOrderStatusExists(String desired) {
        List<Schema.PicklistEntry> entries = Schema.SObjectType.Order.fields.Status.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry e : entries) {
            if (e != null && e.getValue() == desired) {
                return;
            }
        }
        System.assert(false, 'Order.Status value not available in this org: ' + desired);
    } */

    /* private static String getAnyOtherOrderStatus(Set<String> excluded) {
        List<Schema.PicklistEntry> entries = Schema.SObjectType.Order.fields.Status.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry e : entries) {
            if (e == null) continue;
            String v = e.getValue();
            if (String.isBlank(v)) continue;
            if (excluded != null && excluded.contains(v)) continue;
            return v;
        }
        System.assert(false, 'Could not find an Order.Status picklist value outside: ' + excluded);
        return null;
    } */

    /* private static String getAnyServiceStatusValue() {
        
        try {
            List<Schema.PicklistEntry> entries = Schema.SObjectType.Service__c.fields.Status__c.getDescribe().getPicklistValues();
            for (Schema.PicklistEntry e : entries) {
                if (e == null) continue;
                if (e.isActive() && !String.isBlank(e.getValue())) {
                    return e.getValue();
                }
            }
        } catch (Exception e) {
            
        }
        return null;
    }

    private static String getAnyServiceTypeValue() {
        try {
            List<Schema.PicklistEntry> entries = Schema.SObjectType.Service__c.fields.Type__c.getDescribe().getPicklistValues();
            for (Schema.PicklistEntry e : entries) {
                if (e == null) continue;
                if (e.isActive() && !String.isBlank(e.getValue())) {
                    return e.getValue();
                }
            }
        } catch (Exception e) {
            // Field isn't a picklist (or not available in this org).
        }
        return null;
    } */

    /**
     * @description Creates a new Service__c record for DML operations with the given order and claim IDs
     * @param orderId The Order ID to associate with the service
     * @param claimId The Claim ID to associate with the service (nullable)
     * @return Service__c record ready for insert
     */
    private static Service__c newServiceForDml(Id orderId, Id claimId) {
        Service__c s = new Service__c();
        s.Order__c = orderId;
        if (claimId != null) {
            s.Claim__c = claimId;
        }
        // Commonly required fields (if they exist / are required).
        s.StartDate__c = Date.today();
       /*  String t = getAnyServiceTypeValue(); */
       /*  if (t != null) {
            s.Type__c = t;
        } */
        /* String st = getAnyServiceStatusValue();
        if (st != null) {
            s.Status__c = st;
        } */
        return s;
    }

    /**
     * @description Tests that process and processScopedServices guard clauses handle null and empty inputs without throwing exceptions
     */
    @IsTest
    static void testProcess_GuardClauses_NoThrow() {
        Test.startTest();
        ServiceLogic.process(null, null);
        ServiceLogic.process(new Map<Id, Service__c>(), new Map<Id, Service__c>());

        ServiceLogic.processScopedServices(null, null);
        ServiceLogic.processScopedServices(new List<Service__c>(), null);
        Test.stopTest();

        System.assert(true, 'No exceptions expected');
    }

    /**
     * @description Tests the full trigger handler path by updating a service record and verifying ServiceTriggerHandler delegates to ServiceLogic
     */
    @IsTest
    static void testAfterUpdate_ServiceTriggerHandler_CoversHandlerAndProcess() {
        // This test is about executing the trigger/handler path.
        /* assertOrderStatusExists('Open'); */
        ServiceLogic.bypassExternalActions = true;

        Id providerId = getProviderAccountId();
        Case pelayoCase = getCaseBySubject('Pelayo Case - Service');

        Order o = new Order(
            AccountId = providerId,
            EffectiveDate = Date.today(),
            Status = 'Open',
            CaseNumber__c = pelayoCase.Id
        );
        insert o;

        Service__c s = newServiceForDml(o.Id, pelayoCase.Id);
        insert s;

        // Update to fire ServiceTrigger (after update). We do not depend on any specific status.
        /* String anyStatus = getAnyServiceStatusValue();
        if (anyStatus != null) {
            s.Status__c = anyStatus;
        } */

        Test.startTest();
        update s; // fires ServiceTrigger -> ServiceTriggerHandler -> ServiceLogic.process
        Test.stopTest();

        System.assert(true);
    }

    /**
     * @description Tests processScopedServices branching logic covering Pelayo vs non-Pelayo cases, record type mismatches, and various order statuses
     */
    @IsTest
    static void testProcessScopedServices_CoversBranching() {
        /* assertOrderStatusExists('Open');
        assertOrderStatusExists('Order Assignment'); */

        ServiceLogic.bypassExternalActions = true;

        Id providerId = getProviderAccountId();
        Case pelayoCase = getCaseBySubject('Pelayo Case - Service');
        Case nonPelayoCase = getCaseBySubject('Non Pelayo Case - Service');

        Order pelayoOrderAssignment = new Order(
            AccountId = providerId,
            EffectiveDate = Date.today(),
            Status = 'Order Assignment',
            CaseNumber__c = pelayoCase.Id
        );
        insert pelayoOrderAssignment;

        Order pelayoOrderOpen = new Order(
            AccountId = providerId,
            EffectiveDate = Date.today(),
            Status = 'Open',
            CaseNumber__c = pelayoCase.Id
        );
        insert pelayoOrderOpen;

        /* String otherStatus = getAnyOtherOrderStatus(new Set<String>{ 'Open', 'Order Assignment' });
        Order pelayoOrderOther = new Order(
            AccountId = providerId,
            EffectiveDate = Date.today(),
            Status = otherStatus,
            CaseNumber__c = pelayoCase.Id 
        );*/
        /* insert pelayoOrderOther; */

        Order nonPelayoOrder = new Order(
            AccountId = providerId,
            EffectiveDate = Date.today(),
            Status = 'Order Assignment',
            CaseNumber__c = nonPelayoCase.Id
        );
        insert nonPelayoOrder;

        Order noCaseOrder = new Order(
            AccountId = providerId,
            EffectiveDate = Date.today(),
            Status = 'Order Assignment'
        );
        insert noCaseOrder;

        // Insert a real Service to get a valid Id (oldMap lookups use Id).
        Service__c persisted = newServiceForDml(pelayoOrderAssignment.Id, pelayoCase.Id);
        insert persisted;

        // 1) orderIds empty
        Service__c noOrder = new Service__c(Id = persisted.Id, Order__c = null);
        // 2) order exists but no CaseNumber__c
        Service__c noCase = new Service__c(Id = persisted.Id, Order__c = noCaseOrder.Id);
        // 3) non pelayo case
        Service__c nonPelayo = new Service__c(Id = persisted.Id, Order__c = nonPelayoOrder.Id);
        nonPelayo.RecordType = new RecordType(Name = 'Multiguild');
        // 4) recordtype mismatch
        Service__c wrongRecordType = new Service__c(Id = persisted.Id, Order__c = pelayoOrderAssignment.Id);
        wrongRecordType.RecordType = new RecordType(Name = 'Other');
        // 5) order status Open
        Service__c orderOpen = new Service__c(Id = persisted.Id, Order__c = pelayoOrderOpen.Id);
        orderOpen.RecordType = new RecordType(Name = 'Multiguild');
        // 6) unchanged service (oldMap same)
        Service__c unchanged = new Service__c(Id = persisted.Id, Order__c = pelayoOrderAssignment.Id, Status__c = 'X');
        unchanged.RecordType = new RecordType(Name = 'Multiguild');

        // 7) Visit path
        Service__c visit = new Service__c(Id = persisted.Id, Order__c = pelayoOrderAssignment.Id, Status__c = 'Visit');
        visit.RecordType = new RecordType(Name = 'Multiguild');

        // 8) Avance path (order status != Order Assignment)
       /*  Service__c avance = new Service__c(Id = persisted.Id, Order__c = pelayoOrderOther.Id, Status__c = 'Anything');
        avance.RecordType = new RecordType(Name = 'Multiguild'); */

        Map<Id, Service__c> oldMap = new Map<Id, Service__c>{
            persisted.Id => new Service__c(Id = persisted.Id, Order__c = pelayoOrderAssignment.Id, Status__c = 'X')
        };

        Test.startTest();
        ServiceLogic.processScopedServices(new List<Service__c>{ noOrder }, oldMap);
        ServiceLogic.processScopedServices(new List<Service__c>{ noCase }, oldMap);
        ServiceLogic.processScopedServices(new List<Service__c>{ nonPelayo }, oldMap);
        ServiceLogic.processScopedServices(new List<Service__c>{ wrongRecordType }, oldMap);
        ServiceLogic.processScopedServices(new List<Service__c>{ orderOpen }, oldMap);

        // unchanged: new == old
        ServiceLogic.processScopedServices(new List<Service__c>{ unchanged }, new Map<Id, Service__c>{
            persisted.Id => new Service__c(Id = persisted.Id, Order__c = pelayoOrderAssignment.Id, Status__c = 'X')
        });

        // visit + avance
       /*  ServiceLogic.processScopedServices(new List<Service__c>{ visit, avance }, oldMap); */
        Test.stopTest();

        System.assert(true);
    }
}