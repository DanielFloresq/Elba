/**
 * @description       :
 * @author            : Afonso Duque
 * @group             :
 * @last modified on  : 29-01-2026
 * @last modified by  : Afonso Duque
**/
public with sharing class NamedCredentialsCalloutClass {

    /**
	* @description Sends a GET request.
    * @author Afonso Duque | 29-01-2026
    * @param String namedCredentialName
    * @param String endpoint
    * @return HttpResponse
    **/
    public static HttpResponse doGet(
		String namedCredentialName,
		String endpoint
	) {
		HttpRequest req = new HttpRequest();
		req.setEndpoint('callout:' + namedCredentialName + endpoint);
		req.setMethod('GET');
		req.setTimeout(120000);
		Http http = new Http();
		HttpResponse res = http.send(req);
		return res;
	}

	/**
	* @description Sends a POST request.
	* @author Afonso Duque | 29-01-2026
	* @param String namedCredentialName
	* @param String endpoint
	* @param String body
	* @return HttpResponse
	**/
	public static HttpResponse doPost(
		String namedCredentialName,
		String endpoint,
		String body
	) {
		HttpRequest req = new HttpRequest();
		req.setEndpoint('callout:' + namedCredentialName + endpoint);
		req.setMethod('POST');
		req.setBody(body);
		req.setTimeout(120000);
		Http http = new Http();
		HttpResponse res = http.send(req);
		return res;
	}

	/**
	* @description Sends a PUT request.
	* @author Afonso Duque | 29-01-2026
	* @param String namedCredentialName
	* @param String endpoint
	* @param String body
	* @return HttpResponse
	**/
	public static HttpResponse doPut(
		String namedCredentialName,
		String endpoint,
		String body
	) {
		HttpRequest req = new HttpRequest();
		req.setEndpoint('callout:' + namedCredentialName + endpoint);
		req.setMethod('PUT');
		req.setBody(body);
		req.setTimeout(120000);
		Http http = new Http();
		HttpResponse res = http.send(req);
		return res;
	}

	/**
	* @description Sends a PATCH request.
	* @author Afonso Duque | 29-01-2026
	* @param String namedCredentialName
	* @param String endpoint
	* @param String body
	* @return HttpResponse
	**/
	public static HttpResponse doPatch(
		String namedCredentialName,
		String endpoint,
		String body
	) {
		HttpRequest req = new HttpRequest();
		req.setEndpoint('callout:' + namedCredentialName + endpoint);
		req.setMethod('PATCH');
		req.setBody(body);
		req.setTimeout(120000);
		Http http = new Http();
		HttpResponse res = http.send(req);
		return res;
	}

	/**
	* @description Sends a GET request with custom headers.
	* @author Afonso Duque | 29-01-2026
	* @param String namedCredentialName
	* @param String endpoint
	* @param Map<String String> mapHeaders
	* @return HttpResponse
	**/
	public static HttpResponse doGetWithCustomHeaders(
		String namedCredentialName,
		String endpoint,
		Map<String, String> mapHeaders
	) {
		HttpRequest req = new HttpRequest();
		req.setEndpoint('callout:' + namedCredentialName + endpoint);
		req.setMethod('GET');
		for (String key : mapHeaders.keySet()) {
			req.setHeader(key, mapHeaders.get(key));
		}
		req.setTimeout(120000);
		Http http = new Http();
		HttpResponse res = http.send(req);
		return res;
	}

	/**
	* @description Sends a POST request with custom headers.
	* @author Afonso Duque | 29-01-2026
	* @param String namedCredentialName
	* @param String endpoint
	* @param String body
	* @param Map<String String> mapHeaders
	* @return HttpResponse
	**/
	public static HttpResponse doPostWithCustomHeaders(
		String namedCredentialName,
		String endpoint,
		String body,
		Map<String, String> mapHeaders
	) {
		HttpRequest req = new HttpRequest();
		req.setEndpoint('callout:' + namedCredentialName + endpoint);
		req.setMethod('POST');
		req.setBody(body);
		for (String key : mapHeaders.keySet()) {
			req.setHeader(key, mapHeaders.get(key));
		}
		req.setTimeout(120000);
		Http http = new Http();
		HttpResponse res = http.send(req);
		return res;
	}

	/**
	* @description Sends a PUT request with custom headers.
	* @author Afonso Duque | 29-01-2026
	* @param String namedCredentialName
	* @param String endpoint
	* @param String body
	* @param Map<String String> mapHeaders
	* @return HttpResponse
	**/
	public static HttpResponse doPutWithCustomHeaders(
		String namedCredentialName,
		String endpoint,
		String body,
		Map<String, String> mapHeaders
	) {
		HttpRequest req = new HttpRequest();
		req.setEndpoint('callout:' + namedCredentialName + endpoint);
		req.setMethod('PUT');
		req.setBody(body);
		for (String key : mapHeaders.keySet()) {
			req.setHeader(key, mapHeaders.get(key));
		}
		req.setTimeout(120000);
		Http http = new Http();
		HttpResponse res = http.send(req);
		return res;
	}

	/**
	* @description Sends a PATCH request with custom headers.
	* @author Afonso Duque | 29-01-2026
	* @param String namedCredentialName
	* @param String endpoint
	* @param String body
	* @param Map<String String> mapHeaders
	* @return HttpResponse
	**/
	public static HttpResponse doPatchWithCustomHeaders(
		String namedCredentialName,
		String endpoint,
		String body,
		Map<String, String> mapHeaders
	) {
		HttpRequest req = new HttpRequest();
		req.setEndpoint('callout:' + namedCredentialName + endpoint);
		req.setMethod('PATCH');
		req.setBody(body);
		for (String key : mapHeaders.keySet()) {
			req.setHeader(key, mapHeaders.get(key));
		}
		req.setTimeout(120000);
		Http http = new Http();
		HttpResponse res = http.send(req);
		return res;
	}

	/**
	* @description Sends a DELETE request with custom headers.
	* @param String namedCredentialName
	* @param String endpoint
	* @param Map<String String> mapHeaders
	* @return HttpResponse
	**/
	public static HttpResponse doDeleteWithCustomHeaders(
		String namedCredentialName,
		String endpoint,
		Map<String, String> mapHeaders
	) {
		HttpRequest req = new HttpRequest();
		req.setEndpoint('callout:' + namedCredentialName + endpoint);
		req.setMethod('DELETE');
		for (String key : mapHeaders.keySet()) {
			req.setHeader(key, mapHeaders.get(key));
		}
		req.setTimeout(120000);
		Http http = new Http();
		HttpResponse res = http.send(req);
		return res;
	}
}