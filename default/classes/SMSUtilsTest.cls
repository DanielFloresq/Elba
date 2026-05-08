/**
 * @description       : Test class for SMSUtils SMS messaging functionality
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 29-01-2026
 * @last modified by  : Afonso Duque
**/
@isTest
public with sharing class SMSUtilsTest {

    /**
     * @description Verifies that getAuthorizationCredentials returns valid user_key and access_token on a successful HTTP 200 response.
     */
    @isTest
    static void testGetAuthorizationCredentialsSuccess() {

        // Set up the mock response
		List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
                '123;456'
			)
		};

		HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, serviceMocks);
        SMSUtils.AuthCredentials authCredentials = SMSUtils.getAuthorizationCredentials();
        System.AssertEquals('123', authCredentials.user_key);
        System.AssertEquals('456', authCredentials.access_token);
        Test.stopTest();
    }

    /**
     * @description Verifies that getAuthorizationCredentials returns empty credentials when the HTTP response indicates an error.
     */
    @isTest
    static void testGetAuthorizationCredentialsError() {

        // Set up the mock response
		List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
				400,
				'NOK',
                ''
			)
		};

		HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, serviceMocks);
        SMSUtils.AuthCredentials authCredentials = SMSUtils.getAuthorizationCredentials();
        System.AssertEquals('', authCredentials.user_key);
        System.AssertEquals('', authCredentials.access_token);
        Test.stopTest();
    }

    /**
     * @description Verifies that sendSMSMessage returns a successful ServiceResponse when the SMS API responds with HTTP 201.
     */
    @isTest
    static void testSendSMSMessageSuccess() {

        // Set up the mock response
		List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
                '123;456'
			)
			,HttpCalloutMockFactory.generateHttpResponse(
				201,
				'OK',
                '{"result":"OK","order_id":"12345","total_sent":"1","used_credits":"1","remaining_credits":"99","internal_order_id":"abcde"}'
			)
		};

		HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, serviceMocks);
        SMSUtils.ServiceResponse serviceResponse = SMSUtils.sendSMSMessage('123456789', 'Test Message', 'SENDERID');
        System.Assert.isTrue(serviceResponse.isSuccess);
        Test.stopTest();
    }

    /**
     * @description Verifies that sendSMSMessage returns a failed ServiceResponse when the SMS API responds with an error status.
     */
    @isTest
    static void testSendSMSMessageError() {

        // Set up the mock response
		List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
                '123;456'
			)
			,HttpCalloutMockFactory.generateHttpResponse(
				400,
				'NOK',
                ''
			)
		};

		HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, serviceMocks);
        SMSUtils.ServiceResponse serviceResponse = SMSUtils.sendSMSMessage('123456789', 'Test Message', 'SENDERID');
        System.Assert.isFalse(serviceResponse.isSuccess);
        Test.stopTest();
    }

}