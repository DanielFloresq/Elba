/**
 * @description       : Test utility for creating mock HTTP callout responses
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 23-02-2026
 * @last modified by  : Afonso Duque
**/
@isTest
public class HttpCalloutMockFactory implements HttpCalloutMock {

	protected List<HttpResponse> orderedResponses = new List<HttpResponse>();

	/**
	* @description Constructs a mock factory with a single HTTP response built from the given parameters
	* @author Afonso Duque | 23-02-2026
	* @param Integer code
	* @param String status
	* @param String bodyAsString
	**/
	public HttpCalloutMockFactory(
		Integer code,
		String status,
		String bodyAsString
	) {
		this.orderedResponses.add(
			HttpCalloutMockFactory.generateHttpResponse(
				code,
				status,
				bodyAsString
			)
		);
	}


	/**
	* @description Constructs a mock factory with an ordered list of HTTP responses
	* @author Afonso Duque | 23-02-2026
	* @param List<HttpResponse> orderedResponses
	**/
	public HttpCalloutMockFactory(List<HttpResponse> orderedResponses) {
		this.orderedResponses = orderedResponses;
	}

	/**
	* @description Returns the next response in the ordered list and removes it from the queue
	* @author Afonso Duque | 23-02-2026
	* @param HttpRequest req
	* @return HttpResponse
	**/
	public HttpResponse respond(HttpRequest req) {
		return this.orderedResponses.remove(0);
	}

	/**
	* @description Creates an HttpResponse with the specified status code, status text, and body
	* @author Afonso Duque | 23-02-2026
	* @param Integer code
	* @param String status
	* @param String bodyAsString
	* @return HttpResponse
	**/
	public static HttpResponse generateHttpResponse(
		Integer code,
		String status,
		String bodyAsString
	) {
		HttpResponse res = new HttpResponse();
		res.setStatusCode(code);
		res.setStatus(status);
		res.setBody(bodyAsString);
		return res;
	}
}