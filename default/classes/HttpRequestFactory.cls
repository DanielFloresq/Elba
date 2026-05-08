/**
 * @description       : Factory class for creating configured HTTP request instances
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 23-02-2026
 * @last modified by  : Afonso Duque
**/
public with sharing class HttpRequestFactory {

    /**
     * @description Creates and configures an HttpRequest with the specified method, endpoint, headers, and body
     * @param method The HTTP method (e.g., GET, POST, PUT)
     * @param endpoint The target URL for the request
     * @param headers Map of header key-value pairs to set on the request, can be null
     * @param body The request body string, can be null
     * @return Configured HttpRequest instance with a 120-second timeout
     */
    public static HttpRequest createHttpRequest(String method, String endpoint, Map<String, String> headers, String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(method);
        if (headers != null) {
            for (String key : headers.keySet()) {
                req.setHeader(key, headers.get(key));
            }
        }
        if (body != null) {
            req.setBody(body);
        }
        req.setTimeout(120000); // Set timeout to 120 seconds
        return req;
    }
}