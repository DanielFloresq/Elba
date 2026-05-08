@IsTest
private class CaseReopenSelectorControllerTest {

    private static String getAnyReopeningReason() {
        for (Schema.PicklistEntry entry : Case.ReopeningReason__c.getDescribe().getPicklistValues()) {
            if (entry.isActive() && !String.isBlank(entry.getValue())) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static Service__c createService(Id orderId) {
        Service__c serviceRecord = new Service__c(
            Order__c = orderId,
            StartDate__c = Date.today()
        );
        insert serviceRecord;
        return serviceRecord;
    }

    @IsTest
    static void testGetOrdersAndServicesForCase() {
        Account accountRecord = new Account(Name = 'Case Reopen Account');
        insert accountRecord;
        Case caseRecord = new Case(
            Subject = 'Case reopen test',
            Status = 'New',
            Origin = 'Phone'
        );
        insert caseRecord;

        Order firstOrder = TestFactory.createOrder(caseRecord.Id, accountRecord.Id, 'Draft');
        Order secondOrder = TestFactory.createOrder(caseRecord.Id, accountRecord.Id, 'Draft');
        Service__c firstService = createService(firstOrder.Id);
        Service__c secondService = createService(secondOrder.Id);

        Test.startTest();
        List<CaseReopenSelectorController.PicklistOption> reasons = CaseReopenSelectorController.getReopeningReasons();
        List<CaseReopenSelectorController.OrderWithServices> result = CaseReopenSelectorController.getOrdersWithServices(caseRecord.Id);
        List<Service__c> orderServices = CaseReopenSelectorController.getServicesForOrder(firstOrder.Id);
        Test.stopTest();

        System.assert(!reasons.isEmpty(), 'At least one reopening reason should be returned.');
        System.assertEquals(2, result.size(), 'Two Orders should be returned for the Case.');
        System.assertEquals(1, orderServices.size(), 'The first Order should have one Service.');
        System.assertEquals(firstService.Id, orderServices[0].Id, 'The Service should match the created record.');
        System.assertNotEquals(null, secondService.Id, 'The second Service should have been inserted.');
    }

    @IsTest
    static void testSaveSelectionAndSubmitApproval() {
        Account accountRecord = new Account(Name = 'Selection Account');
        insert accountRecord;
        Case caseRecord = new Case(
            Subject = 'Selection persistence test',
            Status = 'New',
            Origin = 'Phone'
        );
        insert caseRecord;

        Order selectedOrder = TestFactory.createOrder(caseRecord.Id, accountRecord.Id, 'Draft');
        Order deselectedOrder = TestFactory.createOrder(caseRecord.Id, accountRecord.Id, 'Draft');
        Service__c selectedService = createService(selectedOrder.Id);
        Service__c deselectedService = createService(deselectedOrder.Id);
        String reopeningReason = getAnyReopeningReason();

        Test.startTest();
        CaseReopenSelectorController.saveReopeningSelection(
            caseRecord.Id,
            reopeningReason,
            new List<Id>{ selectedOrder.Id },
            new List<Id>{ selectedService.Id },
            new List<Id>{ selectedOrder.Id, deselectedOrder.Id },
            new List<Id>{ selectedService.Id, deselectedService.Id }
        );

        CaseReopenSelectorController.bypassApprovalInTests = true;
        CaseReopenSelectorController.ApprovalSubmissionResult approvalResult =
            CaseReopenSelectorController.submitClaimReopeningApproval(caseRecord.Id);
        Test.stopTest();

        Case persistedCase = [
            SELECT ReopeningReason__c, Selected_Order_Ids__c, Selected_Service_Ids__c
            FROM Case
            WHERE Id = :caseRecord.Id
        ];
        Map<Id, Order> ordersById = new Map<Id, Order>([
            SELECT Selected_For_Reopening__c
            FROM Order
            WHERE Id IN :new List<Id>{ selectedOrder.Id, deselectedOrder.Id }
        ]);
        Map<Id, Service__c> servicesById = new Map<Id, Service__c>([
            SELECT Selected_For_Reopening__c
            FROM Service__c
            WHERE Id IN :new List<Id>{ selectedService.Id, deselectedService.Id }
        ]);

        System.assertEquals(reopeningReason, persistedCase.ReopeningReason__c, 'The reopening reason should be persisted on the Case.');
        System.assert(persistedCase.Selected_Order_Ids__c.contains((String)selectedOrder.Id), 'The selected Order Id should be stored on the Case.');
        System.assert(persistedCase.Selected_Service_Ids__c.contains((String)selectedService.Id), 'The selected Service Id should be stored on the Case.');
        System.assertEquals(true, ordersById.get(selectedOrder.Id).Selected_For_Reopening__c, 'Selected Order should be flagged.');
        System.assertEquals(false, ordersById.get(deselectedOrder.Id).Selected_For_Reopening__c, 'Deselected Order should not be flagged.');
        System.assertEquals(true, servicesById.get(selectedService.Id).Selected_For_Reopening__c, 'Selected Service should be flagged.');
        System.assertEquals(false, servicesById.get(deselectedService.Id).Selected_For_Reopening__c, 'Deselected Service should not be flagged.');
        System.assertEquals(true, approvalResult.success, 'Approval submission should report success in test bypass mode.');
    }
}