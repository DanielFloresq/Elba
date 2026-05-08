/**
 * @description       : Test class for c_AssignTasks task assignment lookup operations
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 11-13-2024
 * @last modified by  : Daniel Flores
**/

@isTest
public class test_AssignTasks {
    /**
     * @description Tests the findRecords method of c_AssignTasks with a User search.
     */
    @isTest
    public static void test_AssignTasks() {
        c_AssignTasks.findRecords('t', 'User');
    }
}