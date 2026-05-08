/**
 * @description       : Lightning controller for searching and assigning tasks with lookup functionality
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 11-13-2024
 * @last modified by  : Daniel Flores
**/
public class c_AssignTasks {
    /**
     * @description Searches for records by name using a LIKE query on the specified SObject type
     * @param searchKey The text to search for (matched with prefix wildcard)
     * @param objectName The API name of the SObject to query
     * @return List of matching SObject records (up to 6)
     */
    @AuraEnabled(cacheable=true)  
    public static List<sobject> findRecords(String searchKey, String objectName) {  
        string searchText = '\'' + String.escapeSingleQuotes(searchKey) + '%\'';  
        string query = 'SELECT Id, Name FROM ' + objectName + ' WHERE Name LIKE ' + searchText + (objectName == 'User'? 'AND IsActive = true': '') +' LIMIT 6';  
        return Database.query(query);  
   }  
}