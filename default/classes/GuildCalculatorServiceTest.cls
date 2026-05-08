/**
 * @description       : Test class for GuildCalculatorService guild calculation operations
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 04-02-2026
 * @last modified by  : Afonso Duque
**/
@isTest
public with sharing class GuildCalculatorServiceTest {

    /**
     * @description Tests guild calculation returns expected result for ACCIDENTE damage type
     */
    @isTest
    static void testGetGuild() {
        List<GuildCalculatorService.GuildRequest> requests = new List<GuildCalculatorService.GuildRequest>();
        GuildCalculatorService.GuildRequest req = new GuildCalculatorService.GuildRequest();
        req.grandAccount = 'SLA';
        req.reason = 'testreason';
        req.damage = new List<String>{'ACCIDENTE'};
        req.subreason = 'testsubreason';
        requests.add(req);

        Test.startTest();
        List<GuildCalculatorService.GuildResponse> responses = GuildCalculatorService.getGuild(requests);
        System.AssertEquals(true, !responses.isEmpty(), 'Responses should not be empty');
        System.AssertEquals('NO APLICA', responses[0].guild, 'Guild should be NO APLICA for ACCIDENTE damage');
        Test.stopTest();
    }
}