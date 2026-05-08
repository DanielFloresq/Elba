/**
 * @description       : Test class for SubjectFilterUtil subject filtering operations
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 14-01-2026
 * @last modified by  : Daniel Flores
**/
@isTest
public class SubjectFilterUtilTest {
    /**
     * @description Verifies that consumed values are correctly excluded from the possible values list.
     */
    @isTest
    static void testFiltrarNaoConsumidos_ComConsumidos() {
        List<String> possiveis = new List<String>{'A', 'B', 'C', 'D'};
        List<String> consumidos = new List<String>{'B', 'D'};
        SubjectFilterUtil.SubjectInput input = new SubjectFilterUtil.SubjectInput();
        input.possiveis = possiveis;
        input.consumidos = consumidos;
        List<SubjectFilterUtil.SubjectInput> inputList = new List<SubjectFilterUtil.SubjectInput>{input};
        List<SubjectFilterUtil.SubjectOutput> result = SubjectFilterUtil.filtrarNaoConsumidos(inputList);
        System.assertEquals(1, result.size(), 'Deve retornar um resultado');
        System.assertEquals(new List<String>{'A', 'C'}, result[0].naoConsumidos, 'Deve retornar apenas os não consumidos');
    }

    /**
     * @description Verifies that all possible values are returned when the consumed list is null.
     */
    @isTest
    static void testFiltrarNaoConsumidos_ConsumidosNull() {
        List<String> possiveis = new List<String>{'X', 'Y'};
        SubjectFilterUtil.SubjectInput input = new SubjectFilterUtil.SubjectInput();
        input.possiveis = possiveis;
        input.consumidos = null;
        List<SubjectFilterUtil.SubjectInput> inputList = new List<SubjectFilterUtil.SubjectInput>{input};
        List<SubjectFilterUtil.SubjectOutput> result = SubjectFilterUtil.filtrarNaoConsumidos(inputList);
        System.assertEquals(1, result.size(), 'Deve retornar um resultado');
        System.assertEquals(possiveis, result[0].naoConsumidos, 'Se consumidos for null, deve retornar todos os possíveis');
    }

    /**
     * @description Verifies that an empty result is returned when the possible values list is empty.
     */
    @isTest
    static void testFiltrarNaoConsumidos_PossiveisVazio() {
        List<String> possiveis = new List<String>();
        List<String> consumidos = new List<String>{'A'};
        SubjectFilterUtil.SubjectInput input = new SubjectFilterUtil.SubjectInput();
        input.possiveis = possiveis;
        input.consumidos = consumidos;
        List<SubjectFilterUtil.SubjectInput> inputList = new List<SubjectFilterUtil.SubjectInput>{input};
        List<SubjectFilterUtil.SubjectOutput> result = SubjectFilterUtil.filtrarNaoConsumidos(inputList);
        System.assertEquals(1, result.size(), 'Deve retornar um resultado');
        System.assertEquals(new List<String>(), result[0].naoConsumidos, 'Se possíveis for vazio, deve retornar vazio');
    }

    /**
     * @description Verifies that all possible values are returned when the consumed list is empty.
     */
    @isTest
    static void testFiltrarNaoConsumidos_ConsumidosVazio() {
        List<String> possiveis = new List<String>{'A', 'B'};
        List<String> consumidos = new List<String>();
        SubjectFilterUtil.SubjectInput input = new SubjectFilterUtil.SubjectInput();
        input.possiveis = possiveis;
        input.consumidos = consumidos;
        List<SubjectFilterUtil.SubjectInput> inputList = new List<SubjectFilterUtil.SubjectInput>{input};
        List<SubjectFilterUtil.SubjectOutput> result = SubjectFilterUtil.filtrarNaoConsumidos(inputList);
        System.assertEquals(1, result.size(), 'Deve retornar um resultado');
        System.assertEquals(possiveis, result[0].naoConsumidos, 'Se consumidos for vazio, deve retornar todos os possíveis');
    }
}