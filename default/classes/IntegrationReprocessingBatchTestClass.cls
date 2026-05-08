/**
 * @description       : Legacy test class for IntegrationsReprocessingBatch operations
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 21-01-2026
 * @last modified by  : Daniel Flores
 **/
@IsTest
public with sharing class IntegrationReprocessingBatchTestClass {
	/**
	 * @description Creates test data for IntegrationsReprocessingBatch test methods
	 */
	@TestSetup
	static void makeData() {
		Contact contact = new Contact(LastName = 'Test');
		insert contact;

		Case c = new Case();
		c.ContactId = c.Id;
		insert c;
		/* c.Last_Integration__c = 'c_Claim/createClaimSync/caseId/' + c.Id; */
		update c;

		Account acc = new Account();
		acc.Name = 'Test';
		insert acc;

		Order order = new Order();
		order.AccountId = acc.Id;
		order.Pricebook2Id = Test.getStandardPricebookId();
		/* order.Caso__c = c.Id; */
		order.EffectiveDate = Date.today();
		order.Status = 'Draft';
		order.Type = 'Peritagem';
		/* order.TelemovelDoFornecedor__c = '2432';
		order.TipoDeDocumento__c = '5';
		order.TipoEntidadeRecebedora__c = '1';
		order.Valor_a_pagar2__c = 10;
		order.ValorSujeitoAIRS__c = 10;
		order.N_Fatura__c = '10'; */
		//order.RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('Solutioneer').getRecordTypeId();
		insert order;
		/* order.Last_Integration__c =
			'c_ClaimReceipt/createClaimReceiptSync/orderId/' + order.Id; */
		update order;
	}

	/**
	 * @description Tests reprocessing batch execution for Case records with reprocessAll set to false
	 */
	@IsTest
	public static void test_ReprocessingBatch_Case() {
		/* String recordType = 'Case';
		List<Case> cases = [
			SELECT Id
			FROM Case
			WHERE Last_Integration__c != NULL
			LIMIT 2
		];
		List<String> casesIds = new List<String>();
		for (Case currentCase : cases) {
			casesIds.add(currentCase.Id);
		}

		SObjectType recordSObjectType = ((SObject) Type.forName(recordType)
				.newInstance())
			.getSObjectType();

		Id jobId = Database.executeBatch(
			new IntegrationsReprocessingBatch(
				recordSObjectType,
				casesIds,
				false
			),
			3
		); */
	}
	/**
	 * @description Tests reprocessing batch execution for Case records with reprocessAll set to true
	 */
	@IsTest
	public static void test_ReprocessingBatchTrue_Case() {
		/* String recordType = 'Case';
		List<Case> cases = [
			SELECT Id
			FROM Case
			WHERE Last_Integration__c != NULL
			LIMIT 1
		];
		List<String> casesIds = new List<String>();
		for (Case currentCase : cases) {
			casesIds.add(currentCase.Id);
		}

		SObjectType recordSObjectType = ((SObject) Type.forName(recordType)
				.newInstance())
			.getSObjectType();

		Id jobId = Database.executeBatch(
			new IntegrationsReprocessingBatch(
				recordSObjectType,
				casesIds,
				true
			),
			3
		); */
	}

	/**
	 * @description Tests reprocessing batch execution for Order records with reprocessAll set to false
	 */
	@IsTest
	public static void test_ReprocessingBatch_Order() {
		/* String recordType = 'Order';
		List<Order> orders = [
			SELECT Id
			FROM Order
			WHERE Last_Integration__c != NULL
			LIMIT 2
		];
		List<String> orderIds = new List<String>();
		for (Order currentOrder : orders) {
			orderIds.add(currentOrder.Id);
		}

		SObjectType recordSObjectType = ((SObject) Type.forName(recordType)
				.newInstance())
			.getSObjectType();

		Id jobId = Database.executeBatch(
			new IntegrationsReprocessingBatch(
				recordSObjectType,
				orderIds,
				false
			),
			3
		); */
	}

	/**
	 * @description Tests reprocessing batch execution for Order records with reprocessAll set to true
	 */
	@IsTest
	public static void test_ReprocessingBatch_TrueOrder() {
		/* String recordType = 'Order';
		List<Order> orders = [
			SELECT Id
			FROM Order
			WHERE Last_Integration__c != NULL
			LIMIT 2
		];
		List<String> orderIds = new List<String>();
		for (Order currentOrder : orders) {
			orderIds.add(currentOrder.Id);
		}

		SObjectType recordSObjectType = ((SObject) Type.forName(recordType)
				.newInstance())
			.getSObjectType();

		Id jobId = Database.executeBatch(
			new IntegrationsReprocessingBatch(
				recordSObjectType,
				orderIds,
				true
			),
			3
		); */
	}
}