/**
 * @description       : Utility for filtering unconsumed subject values from a picklist selection
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 14-01-2026
 * @last modified by  : Daniel Flores
**/
public class SubjectFilterUtil {
    public class SubjectInput {
        @InvocableVariable(required=true)
        public List<String> possiveis;
        @InvocableVariable
        public List<String> consumidos;
    }

    public class SubjectOutput {
        @InvocableVariable
        public List<String> naoConsumidos;
    }

    /**
     * @description Invocable method for Flow: receives lists of possible and consumed values and returns the unconsumed ones.
     * @param inputList List of SubjectInput containing possible and consumed value lists.
     * @return List of SubjectOutput with the filtered unconsumed values.
     */
    @InvocableMethod(label='Filtrar Não Consumidos' description='Retorna apenas os valores possíveis que ainda não foram consumidos.')
    public static List<SubjectOutput> filtrarNaoConsumidos(List<SubjectInput> inputList) {
        List<SubjectOutput> result = new List<SubjectOutput>();
        for (SubjectInput input : inputList) {
            Set<String> consumidosSet = new Set<String>();
            if (input.consumidos != null) {
                consumidosSet.addAll(input.consumidos);
            }
            List<String> naoConsumidos = new List<String>();
            for (String valor : input.possiveis) {
                if (!consumidosSet.contains(valor)) {
                    naoConsumidos.add(valor);
                }
            }
            SubjectOutput out = new SubjectOutput();
            out.naoConsumidos = naoConsumidos;
            result.add(out);
        }
        return result;
    }
}