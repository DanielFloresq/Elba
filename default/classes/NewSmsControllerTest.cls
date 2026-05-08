/**
 * @description       :
 * @author            : Afonso Duque
 * @group             :
 * @last modified on  : 03-02-2026
 * @last modified by  : Afonso Duque
**/
@isTest
public class NewSmsControllerTest {

    @TestSetup
    static void makeData(){
        // Get main folder
        Folder mainFolder = [SELECT ID FROM Folder WHERE DeveloperName = 'SMSLAGUNARO' LIMIT 1];

        // Create QuickText in main folder
        QuickText qtMain = new QuickText(
            Name = 'Main QuickText',
            Message = 'Main folder message',
            FolderId = mainFolder.Id
        );
        insert qtMain;

        Case testCase = new Case(
            Subject = 'Test Case for SMS',
            Status = 'New',
            GrandAccount__c = 'SLA'
        );
        insert testCase;
    }

    @isTest
    static void testGetQuickTextsAndFolders(){
        Case testCase = [SELECT Id, GrandAccount__c FROM Case LIMIT 1];
        Test.startTest();
        NewSmsController.QuickTextsFolderWrapper result = NewSmsController.getQuickTexts(testCase.Id);
        System.Assert.areEqual(1, result.quickTextsList.size());
        Test.stopTest();
    }

    @isTest
    static void testGetCase(){

        Case testCase = [SELECT Id FROM Case LIMIT 1];
        List<String> fields = new List<String>{'CaseNumber'};

        Test.startTest();
        testCase = NewSmsController.getCase(testCase.Id, fields);
        System.Assert.isNotNull(testCase.CaseNumber);
        Test.stopTest();
    }

    @isTest
    static void testSendSMSMessage(){

        Case testCase = [SELECT Id, GrandAccount__c, OwnerId FROM Case LIMIT 1];

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
        Boolean success = NewSmsController.sendSMSMessage('123456789', 'Test Message', testCase);
        System.Assert.isTrue(success);
        Test.stopTest();
    }

    @isTest
    static void testCreateTask(){
        Case testCase = [SELECT Id, OwnerId FROM Case LIMIT 1];
        Test.startTest();
        NewSmsController.createTask(testCase, '123456789', 'Test Message');
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :testCase.Id];
        System.Assert.areEqual(1, tasks.size());
        Test.stopTest();
    }
}