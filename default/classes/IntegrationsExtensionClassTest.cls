/**
 * @description       : Test class for IntegrationsExtensionClass integration action routing
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 03-03-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
public class IntegrationsExtensionClassTest {
	/**
	 * @description Verifies that a qualified action routes correctly and throws when the type parameter is missing
	 */
	@IsTest
	static void testQualifiedActionRoutesAndValidatesMissingType() {
		IntegrationsExtensionClass ext = new IntegrationsExtensionClass();
		Exception thrown;
		try {
			ext.call(
				'PelayoWebServiceController.assignEncargoPelayoService',
				new Map<String, Object>{ 'orderId' => '801000000000000AAA' }
			);
		} catch (Exception e) {
			thrown = e;
		}
		System.assertNotEquals(null, thrown);
		System.assert(thrown.getMessage().contains('Missing parameter: type'));
	}

	/**
	 * @description Verifies that calling assignEncargoPelayoService without an orderId parameter throws an exception
	 */
	@IsTest
	static void testMissingOrderIdThrows() {
		IntegrationsExtensionClass ext = new IntegrationsExtensionClass();
		Exception thrown;
		try {
			ext.call(
				'assignEncargoPelayoService',
				new Map<String, Object>{ 'type' => 'AL' }
			);
		} catch (Exception e) {
			thrown = e;
		}
		System.assertNotEquals(null, thrown);
		System.assert(thrown.getMessage().contains('Missing parameter: orderId'));
	}

	/**
	 * @description Verifies that an exception is thrown when no Orders are found for the provided orderId after query
	 */
	@IsTest
	static void testNoOrdersFoundThrowsAfterQuery() {
		Account acc = new Account(Name = 'Ext Acc');
		insert acc;

		Order ord = new Order(AccountId = acc.Id, EffectiveDate = Date.today(), Status = 'Draft');
		insert ord;
		Id ordId = ord.Id;
		delete ord;

		IntegrationsExtensionClass ext = new IntegrationsExtensionClass();
		Exception thrown;
		try {
			ext.call(
				'assignEncargoPelayoService',
				new Map<String, Object>{
					'type' => 'AL',
					'orderId' => String.valueOf(ordId)
				}
			);
		} catch (Exception e) {
			thrown = e;
		}

		System.assertNotEquals(null, thrown);
		System.assert(thrown.getMessage().contains('No Orders found'));
	}

	/**
	 * @description Verifies that calling an unknown action throws a Method not implemented exception
	 */
	@IsTest
	static void testUnknownActionThrows() {
		IntegrationsExtensionClass ext = new IntegrationsExtensionClass();
		Exception thrown;
		try {
			ext.call('unknownAction', new Map<String, Object>());
		} catch (Exception e) {
			thrown = e;
		}
		System.assertNotEquals(null, thrown);
		System.assert(thrown.getMessage().contains('Method not implemented'));
	}
}