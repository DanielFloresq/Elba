/**
 * @description       : Controller for retrieving provider assignments related to an order
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 02-02-2026
 * @last modified by  : Afonso Duque
**/
public with sharing class AssigmentProviderController {

    /**
     * @description Retrieves a list of providers with their phone and email information
     * @param recordId The record Id associated with the order
     * @param isAutomatic Indicates whether the assignment is automatic
     * @return List of Provider wrapper objects containing provider details
     */
    @AuraEnabled
    public static List<Provider> getProviders(Id recordId, Boolean isAutomatic) {
        List<Id> providerIds = new List<Id>{
            '001RR00000zxHPTYA2',
            '001RR00000dkpZmYAI',
            '001RR00000zxHOrYAM'
        };
        List<Account> accounts = [SELECT Id, Name, (SELECT Value__c, Type__c FROM AccountPhones__r) FROM Account WHERE Id IN :providerIds];
        List<Provider> providers = new List<Provider>();
        for(Account acc : accounts){
            String phones = '';
            String emails = '';
            for(AccountInformation__c info : acc.AccountPhones__r){
                if(info.Type__c == 'Phone'){
                    phones += info.Value__c + ' | ';
                }
                if(info.Type__c == 'Email'){
                    emails += info.Value__c + ' | ';
                }
            }
            phones = phones != '' ? phones.substring(0, phones.length() - 3) : '';
            emails = emails != '' ? emails.substring(0, emails.length() - 3) : '';
            providers.add(new Provider(acc.Id, acc.Name, 'testMotive', phones, emails));
        }
        return providers;
    }

    public class Provider{
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String motive;
        @AuraEnabled
        public String phones;
        @AuraEnabled
        public String emails;

        /**
         * @description Constructs a Provider instance with the given details
         * @param id The provider account Id
         * @param name The provider name
         * @param motive The assignment motive
         * @param phones Concatenated phone numbers
         * @param emails Concatenated email addresses
         */
        public Provider(String id, String name, String motive, String phones, String emails){
            this.id = id;
            this.name = name;
            this.motive = motive;
            this.phones = phones;
            this.emails = emails;
        }
    }
}