/**
 * @description       : Batch class for reprocessing failed integration records with configurable extension routing
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 03-03-2026
 * @last modified by  : Daniel Flores
 **/
public with sharing class IntegrationsReprocessingBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {

	private SObjectType sObjectTypeOnBatch { get; set; }
	private String query { get; set; }
	private List<String> recordIdsProperty { get; set; }
	private Boolean isSingleRecord { get; set; }

	
	private static final String DEFAULT_CLASS_NAME = 'IntegrationsExtensionClass';
	private final String FIELD_SEPARATOR = '/';
	private final Integer MIN_FIELD_TOKENS = 4;

	/**
	 * @description Constructs a reprocessing batch for the given SObject type and record Ids
	 * @param sObjectTypeOnBatch The SObject type to process (Case or Order)
	 * @param recordIds List of record Id strings to reprocess, or null for all records with LastIntegration__c
	 * @param isSingleRecord Whether to toggle the Processing__c flag on a single record
	 */
	public IntegrationsReprocessingBatch(
		SObjectType sObjectTypeOnBatch,
		List<String> recordIds,
		Boolean isSingleRecord
	) {
		this.sObjectTypeOnBatch = sObjectTypeOnBatch;
		this.recordIdsProperty = recordIds;
		this.isSingleRecord = isSingleRecord;
	}

	/**
	 * @description Initializes the batch by optionally setting the Processing flag and returning the query locator for records to reprocess
	 * @param bc The batchable context provided by the platform
	 * @return Database.QueryLocator for the records to process
	 */
	public Database.QueryLocator start(Database.BatchableContext bc) {
		System.debug('query: ' + this.query);
		if (this.isSingleRecord && this.sObjectTypeOnBatch == Case.getSObjectType()) {
			
			Case caso = new Case(Id = recordIdsProperty[0]);
			caso.Processing__c = true;
			
			update caso;
		}else if (this.isSingleRecord && this.sObjectTypeOnBatch == Order.getSObjectType()) {
			Order order = new Order(Id = recordIdsProperty[0]);
			order.Processing__c = true;

			update order;
		} 
		if (this.recordIdsProperty == null) {
			return Database.getQueryLocator(
				'SELECT Id, LastIntegration__c FROM ' +
					this.sObjectTypeOnBatch.getDescribe().getName() +
					' WHERE LastIntegration__c != null'
			);
		} else {
			if (this.sObjectTypeOnBatch == Case.getSObjectType()) {
				return Database.getQueryLocator(
					[
						SELECT Id, LastIntegration__c
						FROM Case
						WHERE
							Id IN :this.recordIdsProperty
							AND LastIntegration__c != NULL
					]
				);
			} else if (this.sObjectTypeOnBatch == Order.getSObjectType()) {
				return  Database.getQueryLocator(
					[
						SELECT Id, LastIntegration__c
						FROM Order
						WHERE
							Id IN :this.recordIdsProperty
							AND LastIntegration__c != NULL
					]
				);
			} else {
				return null;
			}
		}
	}

	/**
	 * @description Processes each record in the batch scope by parsing LastIntegration__c and routing to the appropriate Callable extension
	 * @param bc The batchable context provided by the platform
	 * @param scope List of SObject records in the current batch chunk
	 */
	public void execute(Database.BatchableContext bc, List<SObject> scope) {
		Callable defaultExtension = createDefaultExtension();
		for (SObject currentSObject : scope) {
			if (currentSObject.getSObjectType() == Case.getSObjectType()) {
				Case currentCase = (Case) currentSObject;
				if (currentCase.LastIntegration__c == null) {
					throw new ReprocessingException(
						'Last Integration field is empty. Please check the field value and try again.'
					);
				} else {
					List<String> fieldInfo = currentCase.LastIntegration__c.split(
						FIELD_SEPARATOR
					);
					if (fieldInfo.size() < MIN_FIELD_TOKENS) {
						throw new ReprocessingException(
							'Last Integration field is not in the correct format. Please check the field value and try again.'
						);
					} else {
						String className = String.isBlank(fieldInfo[0])
							? DEFAULT_CLASS_NAME
							: fieldInfo[0];
						String methodName = fieldInfo[1];
						Map<String, Object> callParams = buildCallParams(fieldInfo, this.isSingleRecord);
						Callable extension = getExtensionInstance(className, defaultExtension);
						String action = methodName;
						if (extension == defaultExtension && className != DEFAULT_CLASS_NAME) {
							// When the target class isn't Callable, route via default extension.
							action = className + '.' + methodName;
							callParams.put('targetClass', className);
							callParams.put('targetMethod', methodName);
						}
						String result = (String) extension.call(action, callParams);
					}
				}
			}
			else if (
				currentSObject.getSObjectType() == Order.getSObjectType()
			) {
				Order currentOrder = (Order) currentSObject;
				if (currentOrder.LastIntegration__c == null) {
					throw new ReprocessingException(
						'Last Integration field is empty. Please check the field value and try again.'
					);
				} else {
					List<String> fieldInfo = currentOrder.LastIntegration__c.split(
						FIELD_SEPARATOR
					);
					if (fieldInfo.size() < MIN_FIELD_TOKENS) {
						throw new ReprocessingException(
							'Last Integration field is not in the correct format. Please check the field value and try again.'
						);
					} else {
						String className = String.isBlank(fieldInfo[0])
							? DEFAULT_CLASS_NAME
							: fieldInfo[0];
						String methodName = fieldInfo[1];
						Map<String, Object> callParams = buildCallParams(fieldInfo, this.isSingleRecord);
						Callable extension = getExtensionInstance(className, defaultExtension);
						String action = methodName;
						if (extension == defaultExtension && className != DEFAULT_CLASS_NAME) {
							// When the target class isn't Callable, route via default extension.
							action = className + '.' + methodName;
							callParams.put('targetClass', className);
							callParams.put('targetMethod', methodName);
						}
						String result = (String) extension.call(action, callParams);
					}
				}
			}
		}
	}

	/**
	 * @description Instantiates the default integration extension class (IntegrationsExtensionClass)
	 * @return Callable instance of the default extension class
	 */
	private static Callable createDefaultExtension() {
		Type t = Type.forName(DEFAULT_CLASS_NAME);
		if (t == null) {
			throw new ReprocessingException(
				'Default integration class not found: ' + DEFAULT_CLASS_NAME +
				'. Please ensure the class exists and implements System.Callable.'
			);
		}
		Object instance = t.newInstance();
		if (!(instance instanceof Callable)) {
			throw new ReprocessingException(
				'Default integration class does not implement System.Callable: ' + DEFAULT_CLASS_NAME
			);
		}
		return (Callable) instance;
	}

	/**
	 * @description Resolves a Callable extension instance by class name, falling back to the default extension if not found or not Callable
	 * @param className The fully qualified class name to instantiate
	 * @param defaultExtension The fallback Callable instance to use
	 * @return Callable instance for the specified class or the default extension
	 */
	private static Callable getExtensionInstance(String className, Callable defaultExtension) {
		if (String.isBlank(className) || className == 'null' || className == DEFAULT_CLASS_NAME) {
			return defaultExtension;
		}
		Type t = Type.forName(className);
		if (t == null) {
			throw new ReprocessingException(
				'Integration class not found: ' + className +
				'. It must exist and implement System.Callable.'
			);
		}
		Object instance = t.newInstance();
		if (!(instance instanceof Callable)) {
			// Not Callable: route via default extension (IntegrationsExtensionClass)
			return defaultExtension;
		}
		return (Callable) instance;
	}

	/**
	 * @description Builds a parameter map from the parsed LastIntegration__c field tokens
	 * @param fieldInfo List of tokens split from the LastIntegration__c field value
	 * @param sendNotification Whether to include a sendNotification flag in the parameters
	 * @return Map of parameter name-value pairs for the Callable extension
	 */
	private Map<String, Object> buildCallParams(List<String> fieldInfo, Boolean sendNotification) {
		Map<String, Object> callParams = new Map<String, Object>();
		Integer fieldInfoSize = fieldInfo != null ? fieldInfo.size() : 0;
		if (fieldInfoSize < MIN_FIELD_TOKENS) {
			throw new ReprocessingException(
				'Last Integration field is not in the correct format. Please check the field value and try again.'
			);
		}

		// fieldInfo: [0]=className, [1]=methodName, [2]=paramName1, [3]=paramValue1, [4]=paramName2, [5]=paramValue2, ...
		Integer tokensAfterMethod = fieldInfoSize - 2;
		if (Math.mod(tokensAfterMethod, 2) != 0) {
			throw new ReprocessingException(
				'Last Integration field has an odd number of parameter tokens. Expected pairs of paramName/paramValue.'
			);
		}

		for (Integer i = 2; i < fieldInfoSize; i += 2) {
			String paramName = fieldInfo[i];
			Object paramValue = fieldInfo[i + 1];
			if (String.isBlank(paramName)) {
				throw new ReprocessingException(
					'Last Integration field contains an empty parameter name. Please check the field value and try again.'
				);
			}
			callParams.put(paramName, paramValue);
		}

		callParams.put('sendNotification', sendNotification);
		return callParams;
	}

	/**
	 * @description Resets the Processing__c flag on the single record after batch completion
	 * @param bc The batchable context provided by the platform
	 */
	public void finish(Database.BatchableContext bc) {
		if (this.isSingleRecord && this.sObjectTypeOnBatch == Case.getSObjectType()) {
			Case caso = new Case(Id = recordIdsProperty[0]);
			caso.Processing__c = false;
			update caso;
		}else if (this.isSingleRecord && this.sObjectTypeOnBatch == Order.getSObjectType()) {
			Order order = new Order(Id = recordIdsProperty[0]);
			order.Processing__c = false;
			update order;
		}
	}

	public class ReprocessingException extends Exception {
	}
}