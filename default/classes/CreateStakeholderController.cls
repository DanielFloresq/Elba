/**
 * @description       : Controller for creating and updating stakeholders through the MKIS integration
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 20-08-2025
 * @last modified by  : Daniel Flores
**/
public  class CreateStakeholderController {
    
    /**
     * @description Invocable method entry point for creating or updating stakeholders from a Flow
     * @param parameters List of InputWrapper containing stakeholder and order identifiers
     */
    @InvocableMethod(label='Create StakeHolder' description='Create StakeHolder' )
    public static void createStakeHolderFlowUtils(List<InputWrapper> parameters) {
        List<String> strList = new List<String>();
        createStakeHolder(parameters);
    }

    /**
     * @description Builds the stakeholder request body and routes to create or update based on MKISId presence
     * @param parameters List of InputWrapper containing stakeholder and order identifiers
     */
    public static void createStakeHolder(List<InputWrapper> parameters){
        Stakeholders__c stakeHolder = [SELECT Id, Name,Description__c, Designation__c, MKISId__c,Address__Street__s,Address__PostalCode__s,Address__CountryCode__s, Address__City__s   FROM Stakeholders__c WHERE Id = :parameters[0].idStakeHolder];
        requestBody request = new requestBody();
        String address = '';
        if(stakeHolder.Address__Street__s != null) {
            address += stakeHolder.Address__Street__s;
        }
        if(stakeHolder.Address__PostalCode__s != null) {
            if(address != '') address += ', ';
            address += stakeHolder.Address__PostalCode__s;
        }
        if(stakeHolder.Address__City__s != null) {
            if(address != '') address += ', ';
            address += stakeHolder.Address__City__s;
        }
        if(stakeHolder.Address__CountryCode__s != null) {
            if(address != '') address += ', ';
            address += stakeHolder.Address__CountryCode__s;
        }
       
        request.order_id = parameters[0].idOrder;
        
        
        request.name = stakeHolder.Name ;
        request.address = address;
        request.stakeholder_type_name = stakeHolder.Designation__c;
        request.observations = stakeHolder.Description__c;
        request.external_id = stakeHolder.Id;
        request.stakeHolderContactId = parameters[0].idStakeHolderContact;
        String bodyRequest = JSON.serialize(request); 

        if (stakeHolder.MKISId__c != null) {
            updateStakeHolderFutureMethod(bodyRequest);
        }else if(parameters[0].isToCreateInNewService){
            createStakeHolderNewServiceMoment(bodyRequest);
        }else{
            createStakeHolderFutureMethod(bodyRequest);    
        }
        
    }
    

    /**
     * @description Asynchronous method that performs an HTTP POST callout to create a stakeholder in MKIS
     * @param bodyRequest JSON-serialized request body containing stakeholder details
     */
    @future(callout=true)
    public static void createStakeHolderFutureMethod(String bodyRequest) {
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(bodyRequest); 
        String externalId = (String) resultMap.get('external_id'); 
        String stakeHolderContactId = (String) resultMap.get('stakeHolderContactId');
        resultMap.remove('stakeHolderContactId');
        String newJson = JSON.serialize(resultMap);
        Organization org = [SELECT IsSandbox FROM Organization];
        String token = WebServicesUtilities.login();
        Stakeholders__c stakeHolder = [SELECT Id FROM Stakeholders__c WHERE Id = :externalId];
        WebServiceUtils__mdt endpointMdt = [SELECT Endpoint__c FROM WebServiceUtils__mdt WHERE Label = 'CreateStackHolder' AND IsSandbox__c  = :org.IsSandbox LIMIT 1 ];
        
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint (endpointMdt.Endpoint__c);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Content-Type', 'application/json');
        req.setMethod('POST');
        req.setBody(newJson);
        HttpResponse response = http.send(req);
        System.debug(response.getBody());
        responseWrapper responseWrapper = (responseWrapper) JSON.deserialize(response.getBody(), responseWrapper.class);
        stakeHolder.LastIntegrationDescription__c = responseWrapper.message;
        stakeHolder.LastIntegrationDateTime__c = Datetime.now();
        stakeHolder.OnThePortal__c = true;
        if (responseWrapper.data !=  null) {
            stakeHolder.MKISId__c = responseWrapper.data.id;
        }
        CreateContact.InputWrapper input = new CreateContact.InputWrapper();
        input.idStakeHolderContact = stakeHolderContactId;
        input.idStakeHolder = responseWrapper.data.id;
        input.moments = 'm4';
        List<CreateContact.InputWrapper> listInput = new List<CreateContact.InputWrapper>();
        listInput.add(input);
        if (!Test.isRunningTest()) {
            CreateContact.createContactMethod(listInput);
        }
       
        update stakeHolder;
    }
    /**
     * @description Asynchronous method that performs an HTTP PUT callout to update an existing stakeholder in MKIS
     * @param bodyRequest JSON-serialized request body containing stakeholder details
     */
    @future(callout=true)
    public static void updateStakeHolderFutureMethod(String bodyRequest) {
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(bodyRequest); 
        String externalId = (String) resultMap.get('external_id'); 
        String stakeHolderMkisId = (String) resultMap.get('order_id'); 
        resultMap.remove('order_id');
        resultMap.remove('stakeholder_id');
        String stakeHolderContactId = (String) resultMap.get('stakeHolderContactId');
        resultMap.remove('stakeHolderContactId');
        
        Organization org = [SELECT IsSandbox FROM Organization];
        String token = WebServicesUtilities.login();
        Stakeholders__c stakeHolder = [SELECT Id FROM Stakeholders__c WHERE Id = :externalId];
        WebServiceUtils__mdt endpointMdt = [SELECT Endpoint__c FROM WebServiceUtils__mdt WHERE Label = 'CreateStackHolder' AND IsSandbox__c  = :org.IsSandbox LIMIT 1 ];
        
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint (endpointMdt.Endpoint__c + '/' + stakeHolderMkisId);
        
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Content-Type', 'application/json');
        req.setMethod('PUT');
        String newJson = JSON.serialize(resultMap);
        req.setBody(newJson);
        HttpResponse response = http.send(req);
        System.debug(response.getBody());
        responseWrapper responseWrapper = (responseWrapper) JSON.deserialize(response.getBody(), responseWrapper.class);
        stakeHolder.LastIntegrationDescription__c = responseWrapper.message;
        stakeHolder.LastIntegrationDateTime__c = Datetime.now();
        stakeHolder.OnThePortal__c = true;
       
        
        update stakeHolder;
    }

    /**
     * @description Creates a stakeholder in MKIS during the new service creation moment without triggering contact creation
     * @param bodyRequest JSON-serialized request body containing stakeholder details
     */
    public static void createStakeHolderNewServiceMoment(String bodyRequest){
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(bodyRequest); 
        String externalId = (String) resultMap.get('external_id'); 
        String stakeHolderContactId = (String) resultMap.get('stakeHolderContactId');
        resultMap.remove('stakeHolderContactId');
        String newJson = JSON.serialize(resultMap);
        Organization org = [SELECT IsSandbox FROM Organization];
        String token = WebServicesUtilities.login();
        Stakeholders__c stakeHolder = [SELECT Id FROM Stakeholders__c WHERE Id = :externalId];
        WebServiceUtils__mdt endpointMdt = [SELECT Endpoint__c FROM WebServiceUtils__mdt WHERE Label = 'CreateStackHolder' AND IsSandbox__c  = :org.IsSandbox LIMIT 1 ];
        
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint (endpointMdt.Endpoint__c);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Content-Type', 'application/json');
        req.setMethod('POST');
        req.setBody(newJson);
        HttpResponse response = http.send(req);
        System.debug(response.getBody());
        responseWrapper responseWrapper = (responseWrapper) JSON.deserialize(response.getBody(), responseWrapper.class);
        stakeHolder.LastIntegrationDescription__c = responseWrapper.message;
        stakeHolder.LastIntegrationDateTime__c = Datetime.now();
        stakeHolder.OnThePortal__c = true;
        if (responseWrapper.data !=  null) {
            stakeHolder.MKISId__c = responseWrapper.data.id;
        } 
        update stakeHolder;
    }




    public class InputWrapper {
        @InvocableVariable(label='Order Id' )
        public String idOrder;
        @InvocableVariable(label='StakeHolder Id' )
        public String idStakeHolder;
        @InvocableVariable(label='StakeHolderContact Id' )
        public String idStakeHolderContact;
        @InvocableVariable(label='is For Update?' )
        public Boolean isForUpdate;

        @InvocableVariable(label='Create in new Service' )
        public Boolean isToCreateInNewService;
    }

    public class requestBody{
        public String order_id{get;set;}
        public String name{get;set;}
        public String stakeholder_type_name{get;set;}
        public String address {get;set;}
        public String observations {get;set;}
        public String external_id {get;set;}
        public String stakeHolderContactId {get;set;}
    }

    public class responseWrapper {
        public String message;
        public data data;  
    }

    public class data{
        
        public String id;
    }
}