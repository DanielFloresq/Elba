/**
 * @description       : Classe de utils para web services em geral. Objetivo: colocar todos os recursos utilizados frequentemente aqui
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 18-08-2025
 * @last modified by  : Daniel Flores
**/
public with sharing class WebServicesUtilities {

    /**
     * @description Authenticates against the MKIS web service and returns an access token.
     * @return The access token string from the login response.
     */
    //Get Token do serviço MKIS
    public static String login() {
        Organization org = [SELECT IsSandbox FROM Organization];
        WebServiceUtils__mdt endpointMdt = [SELECT Endpoint__c, Email__c, Password__c, ClientSecret__c FROM WebServiceUtils__mdt WHERE Label = 'Login' AND IsSandbox__c =: org.IsSandbox LIMIT 1];
        System.debug(endpointMdt);
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpointMdt.Endpoint__c);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        if (String.isNotBlank(endpointMdt.ClientSecret__c)) {
            request.setHeader('Key', endpointMdt.ClientSecret__c);
        }

        //Definição do body
        Map<String, String> body = new Map<String, String>{
            'email' => endpointMdt.Email__c,
            'password' => endpointMdt.Password__c
        };
        request.setBody(JSON.serialize(body));

        HttpResponse response = http.send(request);
        System.debug(response.getBody());
        if (response.getStatusCode() == 200) {
            if (!Test.isRunningTest()) {
                Map<String, Object> loginResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                if (loginResponse.containsKey('access_token')) {
                    return (String)loginResponse.get('access_token');
                } else {
                    throw new CalloutException('No access_token in login response: ' + response.getBody());
                }
            } else {
                return 'fake-token';
            }
        } else {
            throw new CalloutException('Error STATUS: ' + response.getStatusCode() + ' - ' + response.getBody());
        }
    }
}