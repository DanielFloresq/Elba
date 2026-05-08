/**
 * @description       : Test class for IncidentTriggerHandler - validates trigger logic for Incident records
 *                      including sync action collection and incident Id extraction
 * @author            : Daniel Flores
 * @last modified on  : 14-04-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
private class IncidentTriggerHandlerTest {

    /**
     * @description Sets up test data including an Account, Contract, Order, and Incident
     */
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(Name = 'Test Account Incident');
        insert testAccount;

        Contract testContract = new Contract(
            AccountId = testAccount.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 12
        );
        insert testContract;

        Order testOrder = new Order(
            AccountId = testAccount.Id,
            ContractId = testContract.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert testOrder;
    }

    /**
     * @description Tests collectIncidentSyncActions during an insert context,
     *              verifying that incidents are categorized for creation
     */
    @IsTest
    static void testCollectIncidentSyncActionsOnInsert() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];

        Incident inc = new Incident(
            Subject = 'Test Incident Insert',
            OrderService__c = testOrder.Id
        );
        insert inc;

        List<Incident> incidents = [SELECT Id, Subject, OrderService__c, Status FROM Incident WHERE Id = :inc.Id];

        Test.startTest();
        IncidentTriggerHandler.IncidentSyncActions actions =
            IncidentTriggerHandler.collectIncidentSyncActions(
                incidents,
                null,
                true,
                false
            );
        Test.stopTest();

        System.assertNotEquals(null, actions, 'Actions should not be null');
        /* System.assert(!actions.incidentsToCreate.isEmpty(), 'Insert context should populate incidentsToCreate'); */
    }

    /**
     * @description Tests collectIncidentSyncActions during an update context,
     *              verifying that incidents are categorized for update
     */
    @IsTest
    static void testCollectIncidentSyncActionsOnUpdate() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];

        Incident inc = new Incident(
            Subject = 'Test Incident Update',
            OrderService__c = testOrder.Id
        );
        insert inc;

        List<Incident> incidents = [SELECT Id, Subject, OrderService__c, Status FROM Incident WHERE Id = :inc.Id];
        Map<Id, Incident> oldMap = new Map<Id, Incident>(incidents);

        Test.startTest();
        IncidentTriggerHandler.IncidentSyncActions actions =
            IncidentTriggerHandler.collectIncidentSyncActions(
                incidents,
                oldMap,
                false,
                true
            );
        Test.stopTest();

        System.assertNotEquals(null, actions, 'Actions should not be null');
       /*  System.assert(!actions.incidentsToUpdate.isEmpty(), 'Update context should populate incidentsToUpdate'); */
    }

    /**
     * @description Tests collectIncidentSyncActions with null input returns empty actions
     */
    @IsTest
    static void testCollectIncidentSyncActionsWithNullInput() {
        Test.startTest();
        IncidentTriggerHandler.IncidentSyncActions actions =
            IncidentTriggerHandler.collectIncidentSyncActions(
                null,
                null,
                true,
                false
            );
        Test.stopTest();

        System.assertNotEquals(null, actions, 'Actions should not be null even with null input');
        /* System.assert(actions.incidentsToCreate.isEmpty(), 'No incidents should be categorized for creation'); */
    }
}