/**
 * @description       : Test class for HttpRequestFactory HTTP request creation
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 26-02-2026
 * @last modified by  : Afonso Duque
**/
@isTest
public class HttpRequestFactoryTest {
    /**
     * @description Verifies that createHttpRequest correctly sets method, endpoint, headers, and body
     */
    @isTest
    static void testCreateHttpRequest() {
        String method = 'POST';
        String endpoint = 'https://example.com/api';
        Map<String, String> headers = new Map<String, String>{
            'Content-Type' => 'application/json',
            'Authorization' => 'Bearer token'
        };
        String body = '{"key":"value"}';

        HttpRequest req = HttpRequestFactory.createHttpRequest(method, endpoint, headers, body);

        System.assertEquals(endpoint, req.getEndpoint(), 'Endpoint should match');
        System.assertEquals(method, req.getMethod(), 'Method should match');
        System.assertEquals('application/json', req.getHeader('Content-Type'), 'Content-Type header should match');
        System.assertEquals('Bearer token', req.getHeader('Authorization'), 'Authorization header should match');
        System.assertEquals(body, req.getBody(), 'Body should match');
    }

    /**
     * @description Verifies that createHttpRequest handles null headers and null body without errors
     */
    @isTest
    static void testCreateHttpRequestNullHeadersAndBody() {
        String method = 'GET';
        String endpoint = 'https://example.com/api';
        HttpRequest req = HttpRequestFactory.createHttpRequest(method, endpoint, null, null);

        System.assertEquals(endpoint, req.getEndpoint(), 'Endpoint should match');
        System.assertEquals(method, req.getMethod(), 'Method should match');
    }
}