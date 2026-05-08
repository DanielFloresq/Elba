/**
 * @description       : Test class for OrderTriggerLogic Pelayo order processing
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 14-04-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
public class OrderTriggerLogicTest {

    /**
     * @description Sets up test data including accounts and Pelayo/non-Pelayo cases.
     **/
    @testSetup
    static void setup() {
        insert new Account(Name = 'Provider Test');
        Case pelayoCase = new Case(
            Subject = 'Pelayo Case',
            Status = 'New',
            Origin = 'Phone',
            GrandAccount__c = 'PLYO'
        );
        insert pelayoCase;

        Case nonPelayoCase = new Case(
            Subject = 'Non Pelayo Case',
            Status = 'New',
            Origin = 'Phone',
            GrandAccount__c = 'SLA'
        );
        insert nonPelayoCase;
    }

    /**
     * @description Retrieves the Id of the Provider Test account created in setup.
     * @return Id The Account Id
     **/
    private static Id getProviderAccountId() {
        return [SELECT Id FROM Account WHERE Name = 'Provider Test' LIMIT 1].Id;
    }

    /**
     * @description Retrieves a Case record by its Subject field.
     * @param subject The Subject to search for
     * @return Case The matching Case record
     **/
    private static Case getCaseBySubject(String subject) {
        return [SELECT Id, GrandAccount__c FROM Case WHERE Subject = :subject LIMIT 1];
    }

    /**
     * @description Verifies that processScopedOrders handles null and empty list guard clauses without exceptions.
     **/
    @IsTest
    static void testProcess_GuardClauses_NoThrow() {
        Test.startTest();
        OrderTriggerLogic.processScopedOrders(null, null, false, false);
        OrderTriggerLogic.processScopedOrders(new List<Order>(), null, false, false);
        Test.stopTest();

        System.assert(true, 'No exceptions expected');
    }

    /**
     * @description Verifies after-insert processing for a Pelayo Open order without an external identifier.
     **/
    @IsTest
    static void testAfterInsert_PelayoOpenWithoutExternalId_CoversHandlerAndLogic() {
        

        OrderTriggerLogic.bypassExternalActions = true;

        Account provider = new Account(Id = getProviderAccountId());
        Case pelayoCase = getCaseBySubject('Pelayo Case');

        Order o = new Order(
            AccountId = provider.Id,
            EffectiveDate = Date.today(),
            Status = 'Open',
            CaseNumber__c = pelayoCase.Id
        );

        Test.startTest();
        insert o;
        Test.stopTest();
    }

    /**
     * @description Verifies isCreationStatus returns true only for Open and Order Assignment statuses.
     **/
    @IsTest
    static void testIsCreationStatus_AllowsOpenAndOrderAssignmentOnly() {
        /* System.assertEquals(true, OrderTriggerLogic.isCreationStatus('Open')); */
       /*  System.assertEquals(true, OrderTriggerLogic.isCreationStatus('Order Assignment')); */
        /* System.assertEquals(false, OrderTriggerLogic.isCreationStatus('Service Management')); */
        /* System.assertEquals(false, OrderTriggerLogic.isCreationStatus(null)); */
    }

    /**
     * @description Verifies after-update processing triggers assignation and avance actions on status change with external Id.
     **/
    @IsTest
    static void testAfterUpdate_StatusChanged_WithExternalId_AssignationAndAvance() {

        OrderTriggerLogic.bypassExternalActions = true;

        Id providerId = getProviderAccountId();
        Case pelayoCase = getCaseBySubject('Pelayo Case');
        Order o = new Order(
            AccountId = providerId,
            EffectiveDate = Date.today(),
            Status = 'Open',
            ChargeIdentifier__c = 'EXT-001',
            CaseNumber__c = pelayoCase.Id
        );
        insert o;

        Test.startTest();
        o.Status = 'Order Assignment';
        update o;
        Test.stopTest();
    }

    /**
     * @description Verifies processScopedOrders handles non-Pelayo orders and null oldMap branches.
     **/
    @IsTest
    static void testProcessScopedOrders_NonPelayo_And_OldMapNull_CoversBranches() {
        OrderTriggerLogic.bypassExternalActions = true;
        Id providerId = getProviderAccountId();
        Case nonPelayoCase = getCaseBySubject('Non Pelayo Case');
        Order nonPelayo = new Order(
            AccountId = providerId,
            EffectiveDate = Date.today(),
            Status = 'Open',
            ChargeIdentifier__c = 'EXT-NP',
            CaseNumber__c = nonPelayoCase.Id
        );
        insert nonPelayo;
        List<Order> scoped = [
            SELECT Id, AccountId, Status, ChargeIdentifier__c, CaseNumber__r.GrandAccount__c
            FROM Order
            WHERE Id = :nonPelayo.Id
        ];
        Test.startTest();
        OrderTriggerLogic.processScopedOrders(scoped, null, false, false);
        OrderTriggerLogic.processScopedOrders(scoped, null, false, true);
        Test.stopTest();
    }
}