/**
 * @description       : Test class for IntegrationsReprocessingBatch reprocessing operations
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 04-03-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
public class IntegrationsReprocessingBatchTest {
	/**
	 * @description Creates a test Case record with the specified LastIntegration__c value
	 * @param lastIntegration The LastIntegration__c field value to set
	 * @return The inserted Case record
	 */
	private static Case makeCaseWithLastIntegration(String lastIntegration) {
		Account acc = new Account(Name = 'Batch Case Acc');
		insert acc;
		Contact con = new Contact(LastName = 'Batch Contact', AccountId = acc.Id);
		insert con;
		Case c = new Case(
			Subject = 'Batch Case',
			GrandAccount__c = 'PLYO',
			GCOrderNumber__c = 'GC-TEST',
			ClaimDate__c = Date.today(),
			Coverage__c = 'CE',
			Description = 'Test',
			ContactId = con.Id,
			AccountId = acc.Id,
			LastIntegration__c = lastIntegration
		);
		insert c;
		return c;
	}

	/**
	 * @description Creates a test Order record with the specified LastIntegration__c value
	 * @param lastIntegration The LastIntegration__c field value to set
	 * @return The inserted Order record
	 */
	private static Order makeOrderWithLastIntegration(String lastIntegration) {
		Account acc = new Account(Name = 'Batch Order Acc');
		insert acc;
		Contact con = new Contact(LastName = 'Batch Contact', AccountId = acc.Id);
		insert con;
		Case c = makeCaseWithLastIntegration('TestIntegrationCallable/doSomething/param1/value1');
		Order ord = new Order(
			AccountId = acc.Id,
			BillToContactId = con.Id,
			CaseNumber__c = c.Id,
			Type = 'Serviço Técnico',
			EffectiveDate = Date.today(),
			Status = 'Active',
			LastIntegration__c = lastIntegration
		);
		insert ord;
		return ord;
	}

	/**
	 * @description Verifies that a single Order record is reprocessed using the Callable target class with correct parameters
	 */
	@IsTest
	static void testOrderSingleRecord_UsesCallableTarget() {
		Order ord = makeOrderWithLastIntegration(
			'TestIntegrationCallable/doSomething/param1/value1/param2/value2'
		);

		TestIntegrationCallable.lastAction = null;
		TestIntegrationCallable.lastParams = null;

		Test.startTest();
		Database.executeBatch(
			new IntegrationsReprocessingBatch(
				Order.SObjectType,
				new List<String>{ String.valueOf(ord.Id) },
				true
			),
			1
		);
		Test.stopTest();

		System.assertEquals('doSomething', TestIntegrationCallable.lastAction);
		System.assertNotEquals(null, TestIntegrationCallable.lastParams);
		System.assertEquals('value1', (String) TestIntegrationCallable.lastParams.get('param1'));
		System.assertEquals('value2', (String) TestIntegrationCallable.lastParams.get('param2'));
		System.assertEquals(true, (Boolean) TestIntegrationCallable.lastParams.get('sendNotification'));
	}

	/**
	 * @description Verifies that a single Case record toggles Processing__c and calls the integration correctly
	 */
	@IsTest
	static void testCaseSingleRecord_TogglesProcessingAndCallsIntegration() {
		Case c = makeCaseWithLastIntegration(
			'TestIntegrationCallable/doSomething/param1/value1'
		);

		TestIntegrationCallable.lastAction = null;
		TestIntegrationCallable.lastParams = null;

		Test.startTest();
		Database.executeBatch(
			new IntegrationsReprocessingBatch(
				Case.SObjectType,
				new List<String>{ String.valueOf(c.Id) },
				true
			),
			1
		);
		Test.stopTest();

		Case updated = [SELECT Id, Processing__c FROM Case WHERE Id = :c.Id];
		System.assertEquals(false, updated.Processing__c, 'finish() should reset Processing__c');
		System.assertEquals('doSomething', TestIntegrationCallable.lastAction);
		System.assertEquals(true, (Boolean) TestIntegrationCallable.lastParams.get('sendNotification'));
	}

	/**
	 * @description Verifies that passing null record Ids causes the batch to query all records with LastIntegration__c
	 */
	@IsTest
	static void testRecordIdsNull_StartsFromQuery() {
		Order ord = makeOrderWithLastIntegration(
			'TestIntegrationCallable/doSomething/param1/value1'
		);

		TestIntegrationCallable.lastAction = null;

		Test.startTest();
		Database.executeBatch(
			new IntegrationsReprocessingBatch(Order.SObjectType, null, false),
			1
		);
		Test.stopTest();

		System.assertEquals('doSomething', TestIntegrationCallable.lastAction);
	}

	/**
	 * @description Verifies that routing to the default extension throws when the target class is not Callable
	 */
	@IsTest
	static void testRoutingToDefaultExtension_WhenTargetNotCallable_Throws() {
		Account acc = new Account(Name = 'Route Acc');
		insert acc;
		Order ord = new Order(
			AccountId = acc.Id,
			EffectiveDate = Date.today(),
			Status = 'Draft',
			LastIntegration__c = 'MultiRecordIntegrationController/getObjectType/recordIdString/' + String.valueOf(acc.Id)
		);
		insert ord;

		Exception thrown;
		Test.startTest();
		try {
			Database.executeBatch(
				new IntegrationsReprocessingBatch(
					Order.SObjectType,
					new List<String>{ String.valueOf(ord.Id) },
					false
				),
				1
			);
			Test.stopTest();
		} catch (Exception e) {
			thrown = e;
		}

		System.assertNotEquals(null, thrown);
		System.assert(
			thrown.getMessage().contains('Method not implemented'),
			'Expected "Method not implemented" but got: ' + thrown.getMessage()
		);
	}

	/**
	 * @description Verifies that an invalid LastIntegration__c format throws a ReprocessingException
	 */
	@IsTest
	static void testInvalidFormat_Throws() {
		Order ord = makeOrderWithLastIntegration('TestIntegrationCallable/doSomething/onlyParamName');

		Exception thrown;
		Test.startTest();
		try {
			Database.executeBatch(
				new IntegrationsReprocessingBatch(
					Order.SObjectType,
					new List<String>{ String.valueOf(ord.Id) },
					false
				),
				1
			);
			Test.stopTest();
		} catch (Exception e) {
			thrown = e;
		}

		System.assertNotEquals(null, thrown);
		System.assert(
			thrown.getMessage().contains('not in the correct format'),
			'Expected format error but got: ' + thrown.getMessage()
		);
	}

	/**
	 * @description Verifies that an odd number of parameter tokens in LastIntegration__c throws from buildCallParams
	 */
	@IsTest
	static void testOddNumberOfParameterTokens_ThrowsFromBuildCallParams() {
		Order ord = makeOrderWithLastIntegration('TestIntegrationCallable/doSomething/p1/v1/p2');
		IntegrationsReprocessingBatch batch = new IntegrationsReprocessingBatch(
			Order.SObjectType,
			new List<String>{ String.valueOf(ord.Id) },
			false
		);

		Exception thrown;
		try {
			batch.execute(null, new List<SObject>{ ord });
		} catch (Exception e) {
			thrown = e;
		}
		System.assertNotEquals(null, thrown);
		System.assert(
			thrown.getMessage().contains('odd number of parameter tokens'),
			'Expected odd tokens error but got: ' + thrown.getMessage()
		);
	}

	/**
	 * @description Verifies that an empty parameter name in LastIntegration__c throws from buildCallParams
	 */
	@IsTest
	static void testEmptyParameterName_ThrowsFromBuildCallParams() {
		Order ord = makeOrderWithLastIntegration('TestIntegrationCallable/doSomething//v1');
		IntegrationsReprocessingBatch batch = new IntegrationsReprocessingBatch(
			Order.SObjectType,
			new List<String>{ String.valueOf(ord.Id) },
			false
		);

		Exception thrown;
		try {
			batch.execute(null, new List<SObject>{ ord });
		} catch (Exception e) {
			thrown = e;
		}
		System.assertNotEquals(null, thrown);
		System.assert(
			thrown.getMessage().contains('empty parameter name'),
			'Expected empty param name error but got: ' + thrown.getMessage()
		);
	}

	/**
	 * @description Verifies that referencing a non-existent integration class throws from getExtensionInstance
	 */
	@IsTest
	static void testIntegrationClassNotFound_ThrowsFromGetExtensionInstance() {
		Order ord = makeOrderWithLastIntegration('ClassThatDoesNotExist/doSomething/p1/v1');
		IntegrationsReprocessingBatch batch = new IntegrationsReprocessingBatch(
			Order.SObjectType,
			new List<String>{ String.valueOf(ord.Id) },
			false
		);

		Exception thrown;
		try {
			batch.execute(null, new List<SObject>{ ord });
		} catch (Exception e) {
			thrown = e;
		}
		System.assertNotEquals(null, thrown);
		System.assert(
			thrown.getMessage().contains('Integration class not found'),
			'Expected class not found error but got: ' + thrown.getMessage()
		);
	}
}