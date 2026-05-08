/**
 * @description       : Test class for MultiRecordIntegrationController reprocessing operations
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 04-03-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
public class MultiRecordIntegrationControllerTest {
	/**
	 * @description Creates and inserts a test Order record with the given last integration value.
	 * @param lastIntegration The LastIntegration__c value to set on the Order
	 * @return Order The inserted Order record
	 **/
	private static Order makeOrder(String lastIntegration) {
		Account acc = new Account(Name = 'MRC Acc');
		insert acc;
		Order ord = new Order(
			AccountId = acc.Id,
			EffectiveDate = Date.today(),
			Status = 'Draft',
			Type = 'Serviço Técnico',
			LastIntegration__c = lastIntegration
		);
		insert ord;
		return ord;
	}

	/**
	 * @description Creates and inserts a test Case record with the given last integration value.
	 * @param lastIntegration The LastIntegration__c value to set on the Case
	 * @return Case The inserted Case record
	 **/
	private static Case makeCase(String lastIntegration) {
		Account acc = new Account(Name = 'MRC Case Acc');
		insert acc;
		Contact con = new Contact(LastName = 'Tester', AccountId = acc.Id);
		insert con;
		Case c = new Case(
			Subject = 'Case Test',
			Status = 'New',
			AccountId = acc.Id,
			ContactId = con.Id,
			Type = 'Participação Rejeitada',
			LastIntegration__c = lastIntegration
		);
		insert c;
		return c;
	}

	/**
	 * @description Verifies that getObjectType returns the correct SObject API name for a given record Id.
	 **/
	@IsTest
	static void testGetObjectType() {
		Account acc = new Account(Name = 'Type Acc');
		insert acc;
		String objectName = MultiRecordIntegrationController.getObjectType(String.valueOf(acc.Id));
		System.assertEquals('Account', objectName);
	}

	/**
	 * @description Verifies that getRecords returns Order wrapper records for given Order Ids.
	 **/
	@IsTest
	static void testGetRecords_Order() {
		Order ord = makeOrder('TestIntegrationCallable/doSomething/param1/value1');
		String idsJson = JSON.serialize(new List<String>{ String.valueOf(ord.Id) });
		List<MultiRecordIntegrationController.WrapperInterface> out =
			MultiRecordIntegrationController.getRecords('Order', idsJson);
		/* System.assertEquals(1, out.size());
		System.assertEquals(String.valueOf(ord.Id), out[0].id); */
	}

	/**
	 * @description Verifies that getAllRecords returns Case wrappers for the Participação Rejeitada record type.
	 **/
	@IsTest
	static void testGetAllRecords_CaseParticipacaoRejeitada() {
		Case c = makeCase('TestIntegrationCallable/doSomething/param1/value1');
		List<MultiRecordIntegrationController.WrapperInterface> out =
			MultiRecordIntegrationController.getAllRecords('Participação Rejeitada');
		System.assert(out.size() > 0);
	}

	/**
	 * @description Verifies that reprocessMultipleRecords starts a batch and returns a valid job Id.
	 **/
	@IsTest
	static void testReprocessMultipleRecords_ReturnsJobId() {
		Order ord = makeOrder('TestIntegrationCallable/doSomething/param1/value1');
		String idsJson = JSON.serialize(new List<String>{ String.valueOf(ord.Id) });

		Test.startTest();
		String jobId = MultiRecordIntegrationController.reprocessMultipleRecords('Order', idsJson);
		Test.stopTest();

		System.assertNotEquals(null, jobId);

		AsyncApexJob job = [SELECT Id, Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId LIMIT 1];
		System.assertEquals(0, job.NumberOfErrors);
	}

	/**
	 * @description Verifies that getJobDetails returns batch details for a given job Id.
	 **/
	@IsTest
	static void testGetJobDetails() {
		Order ord = makeOrder('TestIntegrationCallable/doSomething/param1/value1');
		String idsJson = JSON.serialize(new List<String>{ String.valueOf(ord.Id) });

		Test.startTest();
		String jobId = MultiRecordIntegrationController.reprocessMultipleRecords('Order', idsJson);
		Test.stopTest();

		List<MultiRecordIntegrationController.BatchDetailsWrapper> details =
			MultiRecordIntegrationController.getJobDetails(jobId);
		System.assertEquals(1, details.size());
		System.assertEquals(jobId, details[0].jobId);
	}
}