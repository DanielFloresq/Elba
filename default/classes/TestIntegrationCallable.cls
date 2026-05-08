/**
 * @description       : Test implementation of Callable interface for integration testing
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 14-01-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
public class TestIntegrationCallable implements Callable {
	public static String lastAction;
	public static Map<String, Object> lastParams;

	/**
	 * @description Implements the Callable interface call method. Stores the action and params for test assertions and returns 'OK'.
	 * @param action The action name being invoked.
	 * @param params The parameters map passed to the call.
	 * @return An Object result, always 'OK'.
	 */
	public Object call(String action, Map<String, Object> params) {
		lastAction = action;
		lastParams = params;
		return 'OK';
	}
}