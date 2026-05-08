/**
 * @description       : Test class for MKISElbaMessageHandler - validates message sending to MKIS ELBA API
 *                      with HTTP callout mocking
 * @author            : Daniel Flores
 * @last modified on  : 14-01-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
private class MKISElbaMessageHandlerTest {

    /**
     * @description Mock HTTP callout class for simulating MKIS ELBA API responses
     */
    private class MKISElbaMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"message":"Success"}');
            return res;
        }
    }

    /**
     * @description Mock HTTP callout class that returns an error response
     */
    private class MKISElbaErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"message":"Internal Server Error"}');
            return res;
        }
    }

    /**
     * @description Tests sendMessage with a message body and no file attachments
     */
    @IsTest
    static void testSendMessageWithoutFiles() {
        Test.setMock(HttpCalloutMock.class, new MKISElbaMock());

        Test.startTest();
        Boolean result = MKISElbaMessageHandler.sendMessage(
            '801000000000001',
            'Test message body',
            null
        );
        Test.stopTest();

        System.assertEquals(true, result, 'sendMessage should return true on success');
    }

    /**
     * @description Tests sendMessage with a message body and file attachments
     */
    @IsTest
    static void testSendMessageWithFiles() {
        Test.setMock(HttpCalloutMock.class, new MKISElbaMock());

        List<ElbaChatMessageOrderController.File> files = new List<ElbaChatMessageOrderController.File>();
        ElbaChatMessageOrderController.File testFile = new ElbaChatMessageOrderController.File();
        testFile.fileName = 'test.pdf';
        testFile.fileBody = EncodingUtil.base64Encode(Blob.valueOf('test content'));
        files.add(testFile);

        Test.startTest();
        Boolean result = MKISElbaMessageHandler.sendMessage(
            '801000000000001',
            'Test message with attachment',
            files
        );
        Test.stopTest();

        System.assertEquals(true, result, 'sendMessage with files should return true on success');
    }

    /**
     * @description Tests sendMessage returns false when API returns an error
     */
    @IsTest
    static void testSendMessageError() {
        Test.setMock(HttpCalloutMock.class, new MKISElbaErrorMock());

        Test.startTest();
        Boolean result = MKISElbaMessageHandler.sendMessage(
            '801000000000001',
            'Test message error',
            null
        );
        Test.stopTest();

        System.assertEquals(false, result, 'sendMessage should return false on API error');
    }
}