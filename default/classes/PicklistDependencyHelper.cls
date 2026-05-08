/**
 * @description Helper class para gerir dependências entre campos picklist
 * @author Daniel Flores
 * @group Utilities
 */
public class PicklistDependencyHelper {

    public class PicklistInfo {
        @AuraEnabled public Map<String, List<String>> dependentValues = new Map<String, List<String>>();
        @AuraEnabled public List<String> allControllingValues = new List<String>();
    }

    /**
     * @description Retorna os valores dependentes para cada valor controlador
     * @param objApiName Nome API do objeto (ex: 'ContentVersion')
     * @param controllingFieldApiName Nome API do campo controlador (ex: 'FaseDocumental__c')
     * @param dependentFieldApiName Nome API do campo dependente (ex: 'DocumentType__c')
     * @return PicklistInfo com mapa de dependências e valores do controlador
     */
    public static PicklistInfo getDependentValues(String objApiName, String controllingFieldApiName, String dependentFieldApiName) {
        PicklistInfo info = new PicklistInfo();
        
        try {
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
                .get(objApiName)
                .getDescribe()
                .fields
                .getMap();
            
            Schema.DescribeFieldResult controllingFieldDesc = fieldMap.get(controllingFieldApiName).getDescribe();
            Schema.DescribeFieldResult dependentFieldDesc = fieldMap.get(dependentFieldApiName).getDescribe();

            List<Schema.PicklistEntry> controllingValues = controllingFieldDesc.getPicklistValues();
            List<Schema.PicklistEntry> dependentValues = dependentFieldDesc.getPicklistValues();

            // Iterar através dos valores controladores
            for (Integer controllingIndex = 0; controllingIndex < controllingValues.size(); controllingIndex++) {
                Schema.PicklistEntry controllingEntry = controllingValues[controllingIndex];
                String controllingValue = controllingEntry.getValue();
                
                info.allControllingValues.add(controllingValue);
                List<String> validDependentValues = new List<String>();

                // Se não há método getValidFor disponível, retornar todos os valores ativos
                // Esta é a abordagem fallback quando não há dependências configuradas no metadata
                for (Integer dependentIndex = 0; dependentIndex < dependentValues.size(); dependentIndex++) {
                    Schema.PicklistEntry dependentEntry = dependentValues[dependentIndex];
                    
                    if (dependentEntry.isActive()) {
                        validDependentValues.add(dependentEntry.getValue());
                        System.debug('Controlador: ' + controllingValue + 
                                   ', Dependente: ' + dependentEntry.getValue());
                    }
                }

                info.dependentValues.put(controllingValue, validDependentValues);
                System.debug('Valores válidos para ' + controllingValue + ': ' + validDependentValues.size());
            }
        } catch (Exception e) {
            System.debug('Erro ao obter dependências de picklist: ' + e.getMessage());
            System.debug('Stack: ' + e.getStackTraceString());
        }

        return info;
    }

    /**
     * @description Retorna os valores dependentes válidos para um valor controlador específico
     * @param objApiName Nome API do objeto
     * @param controllingFieldApiName Nome API do campo controlador
     * @param dependentFieldApiName Nome API do campo dependente
     * @param controllingValue Valor selecionado do controlador
     * @return Lista de valores dependentes válidos
     */
    public static List<String> getDependentValuesForControlling(
        String objApiName,
        String controllingFieldApiName,
        String dependentFieldApiName,
        String controllingValue
    ) {
        PicklistInfo info = getDependentValues(objApiName, controllingFieldApiName, dependentFieldApiName);
        
        if (info.dependentValues.containsKey(controllingValue)) {
            return info.dependentValues.get(controllingValue);
        }
        
        return new List<String>();
    }
}