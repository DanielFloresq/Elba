/**
 * @description       : Central callout service for MKIS ELBA API integration.
 *                      Uses MKISElba Named Credential and bearer token authentication.
 * @author            : Daniel Flores
 * @group             : MKIS Integration
 * @last modified on  : 26-03-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class MKISElbaCalloutService {

    private static final String NAMED_CREDENTIAL = 'MKISElba';

    /**
    * @description Performs an authenticated POST request to the MKIS ELBA API.
    * @param endpoint The relative endpoint path (e.g. '/services', '/contacts')
    * @param body The JSON body string
    * @return HttpResponse
    **/
    public static HttpResponse doPost(String endpoint, String body) {
        String token = WebServicesUtilities.login();
        Map<String, String> headers = new Map<String, String>{
            'Authorization' => 'Bearer ' + token
        };
        return NamedCredentialsCalloutClass.doPostWithCustomHeaders(
            NAMED_CREDENTIAL, endpoint, body, headers
        );
    }

    /**
    * @description Performs an authenticated PUT request to the MKIS ELBA API.
    * @param endpoint The relative endpoint path (e.g. '/services', '/incidences/123')
    * @param body The JSON body string
    * @return HttpResponse
    **/
    public static HttpResponse doPut(String endpoint, String body) {
        String token = WebServicesUtilities.login();
        Map<String, String> headers = new Map<String, String>{
            'Authorization' => 'Bearer ' + token
        };
        return NamedCredentialsCalloutClass.doPutWithCustomHeaders(
            NAMED_CREDENTIAL, endpoint, body, headers
        );
    }

    /**
    * @description Performs an authenticated GET request to the MKIS ELBA API.
    * @param endpoint The relative endpoint path
    * @return HttpResponse
    **/
    public static HttpResponse doGet(String endpoint) {
        String token = WebServicesUtilities.login();
        Map<String, String> headers = new Map<String, String>{
            'Authorization' => 'Bearer ' + token
        };
        return NamedCredentialsCalloutClass.doGetWithCustomHeaders(
            NAMED_CREDENTIAL, endpoint, headers
        );
    }

    /**
    * @description Performs an authenticated DELETE request to the MKIS ELBA API.
    * @param endpoint The relative endpoint path including resource id (e.g. '/stakeholders/123')
    * @return HttpResponse
    **/
    public static HttpResponse doDelete(String endpoint) {
        String token = WebServicesUtilities.login();
        Map<String, String> headers = new Map<String, String>{
            'Authorization' => 'Bearer ' + token
        };
        return NamedCredentialsCalloutClass.doDeleteWithCustomHeaders(
            NAMED_CREDENTIAL, endpoint, headers
        );
    }
}