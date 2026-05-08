/**
 * @description       : Callable extension class for routing integration actions to appropriate handlers
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 03-03-2026
 * @last modified by  : Daniel Flores
 **/
public with sharing class IntegrationsExtensionClass implements Callable {
	/**
	 * @description Routes the given action to the appropriate integration handler and executes it
	 * @param action The action name identifying which integration to invoke
	 * @param params Map of parameters required by the target integration handler
	 * @return The result of the integration action execution
	 */
	public Object call(String action, Map<String, Object> params) {
		switch on action {
			when 'PelayoWebServiceController.assignEncargoPelayoService' {
				return call('assignEncargoPelayoService', params);
			}
			when 'assignEncargoPelayoService' {
				// type e orderId (pode ser lista separada por vírgula)
				String type = (String) params.get('type');
				String orderIdStr = (String) params.get('orderId');
				List<String> orderIds = new List<String>();
				if (orderIdStr != null) {
					for (String rawId : orderIdStr.split(',')) {
						if (String.isBlank(rawId)) continue;
						String cleaned = rawId.trim();
						if (String.isBlank(cleaned)) continue;
						orderIds.add(cleaned);
					}
				}
				if (String.isBlank(type)) {
					throw new ExtensionMalformedCallException('Missing parameter: type');
				}
				if (orderIds.isEmpty()) {
					throw new ExtensionMalformedCallException('Missing parameter: orderId');
				}
				List<Order> orders = new List<Order>();
				if (!orderIds.isEmpty()) {
					orders = [
						SELECT
							Id,
							CaseNumber__c,
							CaseNumber__r.CaseNumber,
							CaseNumber__r.InsurerClaimReference__c,
							CaseNumber__r.ClaimsHandlerName__c,
							AccountId,
							Account.Name,
							Account.Phone,
							OrderNumber,
							ChargeIdentifier__c,
							CreatedDate,
							EffectiveDate,
							Type,
							ProviderType__c,
							Guild__c,
							Status,
							Observaciones__c,
							Urgent__c,
							ProviderReference__c,
							(
								SELECT
									Name,
									Status__c,
									Type__c,
									Stakeholder__c,
									Stakeholder__r.Name,
									Description__c,
									StartDate__c
								FROM Services__r
							)
						FROM Order
						WHERE Id IN :orderIds
					];
				}
				if (orders.isEmpty()) {
					throw new ExtensionMalformedCallException('No Orders found for provided orderId(s).');
				}
				PelayoWebServiceController.assignEncargoPelayoService(null, orders, type);
				return 'assignEncargoPelayoService';
			}
			
			
			when else {
				throw new ExtensionMalformedCallException(
					'Method not implemented'
				);
			}
		}
	}

	public class ExtensionMalformedCallException extends Exception {
	}
}