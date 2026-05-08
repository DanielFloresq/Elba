/**
 * @description       : Test class for NamedCredentialsCalloutClass callout operations
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 29-01-2026
 * @last modified by  : Afonso Duque
**/
@isTest
public class NamedCredentialsCalloutTest {
	/**
	 * @description Tests doGet performs a successful GET callout and returns the expected response.
	 **/
	@isTest
	static void testDoGet() {
		// Set up the mock response
		List<HttpResponse> responses = new List<HttpResponse>{
			HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
				'{"status":"success"}'
			)
		};

		HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, serviceMocks);

		// Call the method to test
		HttpResponse response = NamedCredentialsCalloutClass.doGet(
			'GetLogin',
			'/blah'
		);

		// Verify the response
		System.assertEquals(200, response.getStatusCode());
		System.assertEquals('{"status":"success"}', response.getBody());
	}

	/**
	 * @description Tests doPost performs a successful POST callout and returns the expected response.
	 **/
	@isTest
	static void testDoPost() {
		// Set up the mock response
		List<HttpResponse> responses = new List<HttpResponse>{
			HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
				'{"status":"success"}'
			)
		};

		HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, serviceMocks);

		// Call the method to test
		HttpResponse response = NamedCredentialsCalloutClass.doPost(
			'GetLogin',
			'/balh',
			'{"key":"value"}'
		);

		// Verify the response
		System.assertEquals(200, response.getStatusCode());
		System.assertEquals('{"status":"success"}', response.getBody());
	}

	/**
	 * @description Tests doPut performs a successful PUT callout and returns the expected response.
	 **/
	@isTest
	static void testDoPut() {
		// Set up the mock response
		List<HttpResponse> responses = new List<HttpResponse>{
			HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
				'{"status":"success"}'
			)
		};

		HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, serviceMocks);

		// Call the method to test
		HttpResponse response = NamedCredentialsCalloutClass.doPut(
			'GetLogin',
			'/balh',
			'{"key":"value"}'
		);

		// Verify the response
		System.assertEquals(200, response.getStatusCode());
		System.assertEquals('{"status":"success"}', response.getBody());
	}

	/**
	 * @description Tests doPatch performs a successful PATCH callout and returns the expected response.
	 **/
	@isTest
	static void testDoPatch() {
		// Set up the mock response
		List<HttpResponse> responses = new List<HttpResponse>{
			HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
				'{"status":"success"}'
			)
		};

		HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, serviceMocks);

		// Call the method to test
		HttpResponse response = NamedCredentialsCalloutClass.doPatch(
			'GetLogin',
			'/balh',
			'{"key":"value"}'
		);

		// Verify the response
		System.assertEquals(200, response.getStatusCode());
		System.assertEquals('{"status":"success"}', response.getBody());
	}

	/**
	 * @description Tests doGetWithCustomHeaders performs a GET callout with custom headers.
	 **/
	@isTest
	static void testDoGetWithCustomHeaders() {
		// Set up the mock response
		List<HttpResponse> responses = new List<HttpResponse>{
			HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
				'{"status":"success"}'
			)
		};

		HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, serviceMocks);

		// Call the method to test
		HttpResponse response = NamedCredentialsCalloutClass.doGetWithCustomHeaders(
			'GetLogin',
			'/blah',
			new Map<String, String>{'Content-Type' => 'application/json'}
		);

		// Verify the response
		System.assertEquals(200, response.getStatusCode());
		System.assertEquals('{"status":"success"}', response.getBody());
	}

	/**
	 * @description Tests doPostWithCustomHeaders performs a POST callout with custom headers.
	 **/
	@isTest
	static void testDoPostWithCustomHeaders() {
		// Set up the mock response
		List<HttpResponse> responses = new List<HttpResponse>{
			HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
				'{"status":"success"}'
			)
		};

		HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, serviceMocks);

		// Call the method to test
		HttpResponse response = NamedCredentialsCalloutClass.doPostWithCustomHeaders(
			'GetLogin',
			'/blah',
			'{"key":"value"}',
			new Map<String, String>{'Content-Type' => 'application/json'}
		);

		// Verify the response
		System.assertEquals(200, response.getStatusCode());
		System.assertEquals('{"status":"success"}', response.getBody());
	}

	/**
	 * @description Tests doPutWithCustomHeaders performs a PUT callout with custom headers.
	 **/
	@isTest
	static void testDoPutWithCustomHeaders() {
		// Set up the mock response
		List<HttpResponse> responses = new List<HttpResponse>{
			HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
				'{"status":"success"}'
			)
		};

		HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, serviceMocks);

		// Call the method to test
		HttpResponse response = NamedCredentialsCalloutClass.doPutWithCustomHeaders(
			'GetLogin',
			'/blah',
			'{"key":"value"}',
			new Map<String, String>{'Content-Type' => 'application/json'}
		);

		// Verify the response
		System.assertEquals(200, response.getStatusCode());
		System.assertEquals('{"status":"success"}', response.getBody());
	}

	/**
	 * @description Tests doPatchWithCustomHeaders performs a PATCH callout with custom headers.
	 **/
	@isTest
	static void testDoPatchWithCustomHeaders() {
		// Set up the mock response
		List<HttpResponse> responses = new List<HttpResponse>{
			HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
				'{"status":"success"}'
			)
		};

		HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, serviceMocks);

		// Call the method to test
		HttpResponse response = NamedCredentialsCalloutClass.doPatchWithCustomHeaders(
			'GetLogin',
			'/blah',
			'{"key":"value"}',
			new Map<String, String>{'Content-Type' => 'application/json'}
		);

		// Verify the response
		System.assertEquals(200, response.getStatusCode());
		System.assertEquals('{"status":"success"}', response.getBody());
	}
}