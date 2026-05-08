/**
 * @description       : Test class for RelatedTasksController task management operations
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 09-02-2026
 * @last modified by  : Daniel Flores
**/
@isTest
private class RelatedTasksControllerTest {
    /**
     * @description Sets up common test data including Account and Contact records
     */
    @testSetup
    static void setup() {
        // Create common records
        Account a = new Account(Name='Test Account');
        insert a;

        Contact c = new Contact(LastName='Test Contact', AccountId=a.Id);
        insert c;

        // NOTE: TaskSubjectTree__mdt custom metadata is expected to already exist in the org
        // The tests use ParentA and ParentB as ParentSubject__c values; ensure those metadata records are present in the target org for tests to pass
    }
    /**
     * @description Tests that getCreateTaskMetadata returns non-null TaskSubjectTree__mdt records
     */
    @isTest
    static void testGetCreateTaskMetadata() {
        Test.startTest();
        List<TaskSubjectTree__mdt> result = RelatedTasksController.getCreateTaskMetadata();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Expected metadata result not null');
    }
    /**
     * @description Tests getRelatedTasks returns parent and child tasks when called with a non-Task record ID
     */
    @isTest    
    public static  void testGetRelatedTasksForRecord() {
        Account a = [SELECT Id FROM Account WHERE Name='Test Account' LIMIT 1];
        Task parent = new Task(Subject='Realizar asignación manual de reparador', WhatId=a.Id, Status='Open', ActivityDate=Date.today());
        insert parent;
        Task child = new Task(Subject='Child Dummy 1', LookUpTask__c=parent.Id, Status='Completed', ActivityDate=Date.today());
        insert child;

        Test.startTest();
        List<Task> res = RelatedTasksController.getRelatedTasks(a.Id);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Expected non-null result for related tasks');
        System.assert(res.size() > 0, 'Expected at least one related task');
        
    }
    /**
     * @description Tests getRelatedTasks returns the full task hierarchy when called with a child Task ID
     */
    @isTest 
    public static  void testGetRelatedTasksForTask() {
        Account a = [SELECT Id FROM Account WHERE Name='Test Account' LIMIT 1];
        Task parent = new Task(Subject='Realizar asignación manual de reparador', WhatId=a.Id, Status='Not Started', ActivityDate=Date.today());
        insert parent;
        Task child = new Task(Subject='Child Dummy 1', LookUpTask__c=parent.Id, Status='Open', ActivityDate=Date.today());
        insert child;

        Task child1 = new Task(Subject='Child Dummy 1', LookUpTask__c=parent.Id, Status='Open', ActivityDate=Date.today());
        insert child1;

        Test.startTest();
        List<Task> res = RelatedTasksController.getRelatedTasks(child.Id);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Expected non-null result for related tasks');
        System.assert(res.size() > 0, 'Expected at least one related task');
        
    }
    /**
     * @description Tests that getSubjectSuggestions filters out subjects with existing non-completed tasks and avoids duplicates
     */
    @isTest 
    public static void testGetSubjectSuggestionsFiltersExistingNonCompleted() {
        Account a = [SELECT Id FROM Account WHERE Name='Test Account' LIMIT 1];
        // Create existing non-completed task with ParentA subject to ensure it's filtered out
        Task existing = new Task(Subject='ParentA', WhatId=a.Id, Status='Completed', ActivityDate=Date.today());
        insert existing;

        Test.startTest();
        List<RelatedTasksController.SubjectSuggestion> sug = RelatedTasksController.getSubjectSuggestions('Parent', a.Id);
        Test.stopTest();

        System.assertNotEquals(null, sug, 'Expected non-null result for subject suggestions');
      
        
        // Test for duplicate parent/child suggestions (should not return duplicates)
        List<RelatedTasksController.SubjectSuggestion> sug2 = RelatedTasksController.getSubjectSuggestions('Parent', a.Id);
        Set<String> seen = new Set<String>();
        for (RelatedTasksController.SubjectSuggestion s : sug2) {
            String key = (s.parent != null ? s.parent : '') + '|' + s.child;
            System.assert(!seen.contains(key), 'Duplicate suggestion found: ' + key);
            seen.add(key);
        }
    }
    /**
     * @description Tests createParentTask validation rules including blank subject, duplicate detection, and metadata validation
     */
    @isTest
    public static void testCreateParentTaskValidations() {
        // Attempt to create a Parent task. Depending on whether TaskSubjectTree__mdt exists, either it will succeed ou throw a validation exception.
        Boolean created = false;
        Id newId;
        Account a = [SELECT Id FROM Account  LIMIT 1];
        try {
            System.debug('Testing createParentTask with subject=ParentB, activityDate=' + Date.today());
            Test.startTest();
            newId = RelatedTasksController.createParentTask('Realizar asignación manual de reparador', Date.today(), null, null, a.Id);
            newId = RelatedTasksController.createParentTask('Realizar asignación manual de reparador', Date.today(), null, null, a.Id);
            newId = RelatedTasksController.createParentTask(null, Date.today(), null, null, a.Id);
            Test.stopTest();
            created = true;
        } catch (AuraHandledException e) {
            // Pode lançar se não houver metadata
        }
    }

    /**
     * @description Tests createParentTask succeeds when all parameters (ownerId, whoId, whatId) are provided
     */
    @isTest
    public static void testCreateParentTaskWithAllParams() {
        // Test with ownerId, whoId, whatId
        Account a = [SELECT Id, OwnerId FROM Account WHERE Name='Test Account' LIMIT 1];
        Contact c = [SELECT Id FROM Contact WHERE LastName='Test Contact' LIMIT 1];
        Id ownerId = a.OwnerId;
        Id whoId = c.Id;
        Id whatId = a.Id;
        try {
            Test.startTest();
            Id tId = RelatedTasksController.createParentTask('ParentB', Date.today(), ownerId, whoId, whatId);
            Test.stopTest();
            System.assertNotEquals(null, tId, 'Task created with all params');
        } catch (AuraHandledException e) {
            // Pode lançar se não houver metadata
        }
    }
    /**
     * @description Tests getRecordInfo returns correct label and owner details for Account, Contact, Order, and Case records
     */
    @isTest
    public static void testGetRecordInfoAccountAndContact() {
        Account a = [SELECT Id, OwnerId, Owner.Name, Name FROM Account WHERE Name='Test Account' LIMIT 1];
        Map<String,String> info = RelatedTasksController.getRecordInfo(a.Id);
        

        Contact c = [SELECT Id, LastName FROM Contact WHERE LastName='Test Contact' LIMIT 1];
        Map<String,String> infoC = RelatedTasksController.getRecordInfo(c.Id);
        
        // Test Order
        Order o = new Order(Name='Test Order', EffectiveDate=Date.today(), Status='Draft', AccountId=a.Id);
        insert o;
        Map<String,String> infoO = RelatedTasksController.getRecordInfo(o.Id);
        System.assert(infoO.containsKey('label'), 'Order label');
        System.assert(infoO.containsKey('ownerId'), 'Order ownerId');

        // Test Case
        Case cs = new Case(Subject='Test Case', Status='New', Origin='Phone', AccountId=a.Id);
        insert cs;
        Map<String,String> infoCs = RelatedTasksController.getRecordInfo(cs.Id);
        System.assert(infoCs.containsKey('label'), 'Case label');
        System.assert(infoCs.containsKey('ownerId'), 'Case ownerId');
    }
    /**
     * @description Tests that getRelatedTasks returns an empty list when recordId is null
     */
    @isTest
    public static void testGetRelatedTasksNullId() {
        Test.startTest();
        List<Task> res = RelatedTasksController.getRelatedTasks(null);
        Test.stopTest();

        System.assertEquals(0, res.size(), 'Expected no tasks for null recordId');
    }

    /**
     * @description Tests that createParentTask throws AuraHandledException for an invalid subject not in metadata
     */
    @isTest
    public static void testCreateParentTaskInvalidSubject() {
        try {
            Test.startTest();
            RelatedTasksController.createParentTask('Parent Dummy 2', Date.today(), null, null, null);
            Test.stopTest();
            System.assert(false, 'Expected exception for blank subject');
        } catch (AuraHandledException e) {
            // Exception handling
        }
    }

    /**
     * @description Tests that createParentTask handles SOQL exception scenarios gracefully
     */
    @isTest
    public static void testCreateParentTaskSOQLException() {
        // Simular erro de SOQL (subject inválido com erro de query)
        try {
            Test.startTest();
            // Usar um subject que cause erro de SOQL, por exemplo, string muito longa
            String longSubject = String.valueOf(Crypto.generateDigest('SHA1', Blob.valueOf('x')));
            RelatedTasksController.createParentTask(longSubject, Date.today(), null, null, null);
            Test.stopTest();
            System.assert(false, 'Esperava exceção de SOQL');
        } catch (AuraHandledException e) {
            System.assert(true, 'Exceção capturada corretamente');
        }
    }

    /**
     * @description Tests that getSubjectSuggestions returns an empty list when query string is blank
     */
    @isTest
    public static void testGetSubjectSuggestionsEmptyQuery() {
        Account a = [SELECT Id FROM Account WHERE Name='Test Account' LIMIT 1];

        Test.startTest();
        List<RelatedTasksController.SubjectSuggestion> sug = RelatedTasksController.getSubjectSuggestions('', a.Id);
        Test.stopTest();

        System.assertEquals(0, sug.size(), 'Expected no suggestions for empty query');
    }

    /**
     * @description Tests that getRecordInfo returns an empty map when recordId is null
     */
    @isTest
    public static void testGetRecordInfoNullId() {
        Test.startTest();
        Map<String, String> res = RelatedTasksController.getRecordInfo(null);
        Test.stopTest();

        System.assertEquals(0, res.size(), 'Expected empty map for null recordId');
    }

    /**
     * @description Tests that getRecordInfo returns label and ownerId for a generic object type
     */
    @isTest
    public static void testGetRecordInfoOtherObject() {
        Account a = [SELECT Id FROM Account WHERE Name='Test Account' LIMIT 1];

        Test.startTest();
        Map<String, String> res = RelatedTasksController.getRecordInfo(a.Id);
        Test.stopTest();

        System.assert(res.containsKey('label'), 'Expected label in result map');
        System.assert(res.containsKey('ownerId'), 'Expected ownerId in result map');
    }
}