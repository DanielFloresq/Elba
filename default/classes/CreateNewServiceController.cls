/**
 * @description       : Controller for creating and updating MKIS services from Order records
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 07-05-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class CreateNewServiceController {

    private static final Set<String> VALID_STAKEHOLDER_TYPES = new Set<String>{ 'C', 'P' };

    /**
     * @description Validates mandatory fields on an Order record and returns a list of missing field keys
     * @param recordId The Order record Id to validate
     * @return List of missing mandatory field key names
     */
    @AuraEnabled
    public static List<String> validateMandatoryFields(String recordId) {
        if (String.isBlank(recordId) || !recordId.startsWith('801')) {
            return new List<String>();
        }

        Order orderRecord = [SELECT 
            OrderNumber,
            Guild__c,
            Urgent__c,
            OPFVTSIndicatorsPresent__c,
            CaseNumber__c,
            CaseNumber__r.CaseNumber,
            CaseNumber__r.GrandAccount__c,
            CaseNumber__r.ClaimDate__c,
            CaseNumber__r.Description,
            CaseNumber__r.ClaimsHandlerName__c,
            CaseNumber__r.ClaimsHandlerEmail__c,
            CaseNumber__r.RelationshiptotheInsured__c,
            CaseNumber__r.ParticipationDate__c,
            //CaseNumber__r.SCC__c,
            //CaseNumber__r.CorrosionPresent__c,
            CaseNumber__r.Marcadores__c,
            Account.Name,
            Account.TaxNumber__c,
            Account.Email__c,
            Account.Phone,
            BillToContact.Name,
            BillToContact.PolicyNumber__c,
            BillToContact.Phone,
            BillToContact.MobilePhone,
            BillToContact.Email,
            BillToContact.IDNumber__c,
            BillToContact.MailingStreet,
            BillToContact.MailingCity,
            BillToContact.MailingPostalCode,
            BillToContact.MailingState,
            BillToContact.MailingCountry,
            BillToContact.PolicyStartDate__c,
            BillToContact.LineOfBusiness__c,
            BillToContact.IsVIP__c,
            Id 
            FROM Order 
            WHERE Id = :recordId
            LIMIT 1
        ];

        return collectMissingMandatoryFields(orderRecord);
    }

    /**
     * @description Filters a list of Order Ids, returning only those with all mandatory fields populated
     * @param recordIds List of Order Ids to evaluate
     * @return List of Order Ids that have all mandatory fields filled
     */
    public static List<Id> filterOrdersWithMandatoryFields(List<Id> recordIds) {
        List<Id> validOrderIds = new List<Id>();
        if (recordIds == null || recordIds.isEmpty()) {
            return validOrderIds;
        }

        for (Order orderRecord : [SELECT
            OrderNumber,
            Guild__c,
            Urgent__c,
            OPFVTSIndicatorsPresent__c,
            CaseNumber__c,
            CaseNumber__r.CaseNumber,
            CaseNumber__r.GrandAccount__c,
            CaseNumber__r.ClaimDate__c,
            CaseNumber__r.Description,
            CaseNumber__r.ClaimsHandlerName__c,
            CaseNumber__r.ClaimsHandlerEmail__c,
            CaseNumber__r.RelationshiptotheInsured__c,
            CaseNumber__r.ParticipationDate__c,
            //CaseNumber__r.SCC__c,
            //CaseNumber__r.CorrosionPresent__c,
            CaseNumber__r.Marcadores__c,
            Account.Name,
            Account.TaxNumber__c,
            Account.Email__c,
            Account.Phone,
            BillToContact.Name,
            BillToContact.PolicyNumber__c,
            BillToContact.Phone,
            BillToContact.MobilePhone,
            BillToContact.Email,
            BillToContact.IDNumber__c,
            BillToContact.MailingStreet,
            BillToContact.MailingCity,
            BillToContact.MailingPostalCode,
            BillToContact.MailingState,
            BillToContact.MailingCountry,
            BillToContact.PolicyStartDate__c,
            BillToContact.LineOfBusiness__c,
            BillToContact.IsVIP__c,
            Id
            FROM Order
            WHERE Id IN :recordIds
        ]) {
            if (collectMissingMandatoryFields(orderRecord).isEmpty()) {
                validOrderIds.add(orderRecord.Id);
            }
            System.debug(collectMissingMandatoryFields(orderRecord));
        }

        return validOrderIds;
    }

    /**
     * @description Invocable method that redirects to the service creation method
     * @param input List containing the record Id (Order or Case) to process
     */
    @InvocableMethod(label='Create New Service' iconName='slds:standard:service_contract')
    public static void redirectMethod(List<String> input) {
        /* System.debug(input);
        if (input[0].startsWith('801')) {

           
            order order = [SELECT ID,BillToContactId, CaseNumber__c  FROM Order WHERE Id =:input[0].replaceAll('[()]', '')];
            Contact contact = [SELECT ID,MailingCity,MailingLatitude,MailingLongitude, MailingPostalCode, MailingStreet, Email, Name, MobilePhone FROM Contact WHERE Id =:order.BillToContactId ];
            List<Stakeholders__c> listStakeHolders = new List<Stakeholders__c>();
            listStakeHolders = [SELECT Id FROM Stakeholders__c WHERE Case__c = :order.CaseNumber__c AND Name = :contact.Name  LIMIT 1];
           
            if (listStakeHolders.isEmpty()) {
                Stakeholders__c  newStakeHolder =  new Stakeholders__c();
                newStakeHolder.Address__City__s = contact.MailingCity;
                newStakeHolder.Address__Latitude__s = contact.MailingLatitude;
                newStakeHolder.Address__Longitude__s = contact.MailingLongitude;
                newStakeHolder.Address__PostalCode__s = contact.MailingPostalCode;
                newStakeHolder.Address__Street__s = contact.MailingStreet;
                newStakeHolder.Email__c = contact.Email;
                newStakeHolder.Name = contact.Name;
                newStakeHolder.Phone__c = contact.MobilePhone;
                newStakeHolder.Designation__c = 'Policyholder';
                newStakeHolder.Case__c = order.CaseNumber__c;
                insert newStakeHolder;
            }
        } */
        

        createNewServiceMethod(input); 
        
    }

    /**
     * @description Asynchronous method that creates or updates a service in MKIS via HTTP callout
     * @param input List containing the record Id (Order or Case) to process
     */
    @future(callout=true)
    @AuraEnabled
    public static void createNewServiceMethod(List<String> input) {
        String token = WebServicesUtilities.login();
        System.debug(token);

        Organization org = [SELECT IsSandbox FROM Organization];
        WebServiceUtils__mdt serviceConfig = [SELECT Endpoint__c FROM WebServiceUtils__mdt WHERE Label = 'Create New Service' AND IsSandbox__c = :org.IsSandbox LIMIT 1];
        Http http = new Http();

        if (input[0].startsWith('801')) {
            Order order = [SELECT 
                CaseNumber__r.GrandAccount__c,
                CaseNumber__r.GCOrderNumber__c,
                CaseNumber__r.ClaimDate__c,
                CaseNumber__r.ClaimsHandlerEmail__c,
                CaseNumber__r.ClaimsHandlerName__c,
                BillToContact.Name,
                CaseNumber__r.Coverage__c,
                CaseNumber__r.Description,
                CaseNumber__r.RelationshiptotheInsured__c,
                CaseNumber__r.ParticipationDate__c,
                //CaseNumber__r.SCC__c,
                //CaseNumber__r.CorrosionPresent__c,
                CaseNumber__r.Marcadores__c,
                BillToContact.PolicyNumber__c,
                BillToContact.MailingAddress,
                BillToContact.MailingStreet,
                BillToContact.Phone,
                BillToContact.MobilePhone,
                BillToContact.Email,
                BillToContact.IDNumber__c,
                BillToContact.BuildingCapital__c,
                BillToContact.FillingCapital__c,
                BillToContact.LiabilityCapital__c,
                BillToContact.PolicyStartDate__c,
                BillToContact.LineOfBusiness__c,
                BillToContact.IsVIP__c,
                BillToContact.MailingCity,
                BillToContact.MailingState,
                BillToContact.MailingCountry,
                Account.Name,
                Account.TaxNumber__c,
                Account.Phone,
                Account.Email__c,
                Guild__c,
                Urgent__c,
                OPFVTSIndicatorsPresent__c,
                OrderNumber,
                CaseNumber__r.CaseNumber,
                BillToContact.MailingPostalCode,
                CaseNumber__c,
                Type,
                LastIntegrationDateTime__c, 
                LastIntegrationDescription__c,
                iFrame__c,
                UrlLinkStatus__c,
                BillToContactId ,
                Id 
                FROM Order 
                WHERE Id = :input[0]
            ];
            processOrder(order, token, serviceConfig, http, 'Create');
            update order;
        } 
        else if (input[0].startsWith('500')) {
            List<Order> orders = [SELECT 
                CaseNumber__r.GrandAccount__c,
                CaseNumber__r.GCOrderNumber__c,
                CaseNumber__r.ClaimDate__c,
                CaseNumber__r.ClaimsHandlerEmail__c,
                CaseNumber__r.ClaimsHandlerName__c,
                BillToContact.Name,
                CaseNumber__r.Coverage__c,
                CaseNumber__r.Description,
                CaseNumber__r.RelationshiptotheInsured__c,
                CaseNumber__r.ParticipationDate__c,
                //CaseNumber__r.SCC__c,
                //CaseNumber__r.CorrosionPresent__c,
                CaseNumber__r.Marcadores__c,
                BillToContact.PolicyNumber__c,
                BillToContact.MailingAddress,
                BillToContact.MailingStreet,
                BillToContact.MailingCity,
                BillToContact.MailingState,
                BillToContact.MailingCountry,
                BillToContact.Phone,
                BillToContact.MobilePhone,
                BillToContact.Email,
                BillToContact.IDNumber__c,
                BillToContact.BuildingCapital__c,
                BillToContact.FillingCapital__c,
                BillToContact.LiabilityCapital__c,
                BillToContact.PolicyStartDate__c,
                BillToContact.LineOfBusiness__c,
                BillToContact.IsVIP__c,
                Account.Name,
                Account.TaxNumber__c,
                Account.Phone,
                Account.Email__c,
                Guild__c,
                Urgent__c,
                OPFVTSIndicatorsPresent__c,
                OrderNumber,
                CaseNumber__r.CaseNumber,
                BillToContact.MailingPostalCode,
                CaseNumber__c,
                Type,
                LastIntegrationDateTime__c, 
                LastIntegrationDescription__c,
                iFrame__c,
                UrlLinkStatus__c,
                BillToContactId ,
                Id 
                FROM Order 
                WHERE CaseNumber__c = :input[0]
            ];

            for (Order order : orders) {
                try {
                    processOrder(order, token, serviceConfig, http, 'Update');
                } catch (Exception ex) {
                    System.debug('Erro ao processar Order: ' + order.Id + ' -> ' + ex.getMessage());
                    AlertIntegration__e eventInstance = new AlertIntegration__e();
                    eventInstance.OrderCreated__c = order.Id;
                    eventInstance.UserId__c = UserInfo.getUserId();
                    eventInstance.IsSuccess__c = false;
                    eventInstance.Message__c = ex.getMessage();
                    EventBus.publish(eventInstance);
                }
            }
            update orders;
        }
    }

    /**
     * @description Processes a single Order by building the request, sending the HTTP callout, and handling the response
     * @param order The Order record to process
     * @param token The authentication token for the API
     * @param config The custom metadata containing the endpoint URL
     * @param http The Http instance used to send the request
     * @param methodType The operation type - Create or Update
     */
    private static void processOrder(Order order, String token, WebServiceUtils__mdt config, Http http, String methodType) {
        Map<String, Object> body = buildRequestBody(order);
        Map<String, Object> cleanedMap = new Map<String, Object>();
    
        for (String key : body.keySet()) {
            if (body.get(key) != null) {
                cleanedMap.put(key, body.get(key));
            }
        }
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(config.Endpoint__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setBody(JSON.serialize(body));

        System.debug(JSON.serialize(cleanedMap));

        HttpResponse res = http.send(req);
        ServiceResponse response = new  ServiceResponse();
        response200 response200 = new  response200();
        AlertIntegration__e eventInstance = new AlertIntegration__e();
        eventInstance.OrderCreated__c = order.Id;
        eventInstance.UserId__c = UserInfo.getUserId();

        try {
            System.debug(res.getBody());
            if (res.getStatusCode() == 200) {
                response200 = (response200) JSON.deserialize(res.getBody(), response200.class);
            }else{
                response = (ServiceResponse) JSON.deserialize(res.getBody(), ServiceResponse.class);
            }
            
        } catch (Exception e) {
            eventInstance.IsSuccess__c = false;
        }

        if (res.getStatusCode() == 200) {
            eventInstance.IsSuccess__c = true;
            
    
        
            
            List<Order> listOrders = new List<Order>();
            listOrders = [SELECT Id FROM Order WHERE CaseNumber__c =: order.CaseNumber__c AND UrlLinkStatus__c = true];
            if (listOrders.isEmpty()) {
                Stakeholders__c  newStakeHolder =  [SELECT Id FROM Stakeholders__c WHERE Case__c = :order.CaseNumber__c AND Name =:order.BillToContact.Name Order by CreatedDate DESC LIMIT 1];
                CreateStakeholderController.InputWrapper inputs = new CreateStakeholderController.InputWrapper();
                inputs.idOrder = order.Id;
                inputs.idStakeholder = newStakeHolder.Id;
                inputs.isToCreateInNewService = true;
                List<CreateStakeholderController.InputWrapper> listInputs = new List<CreateStakeholderController.InputWrapper>();
                listInputs.add(inputs);
                CreateStakeholderController.createStakeHolder(listInputs);
            }
            

            
        } else {
            eventInstance.IsSuccess__c = false;
        }

        if (res.getStatusCode() != 200) {
            eventInstance.IsSuccess__c = false;
            order.LastIntegrationDateTime__c = System.now();
            order.LastIntegrationDescription__c = response != null ? response.message : 'Error on code or webservice!';
            eventInstance.Message__c = response != null ? response.message : 'Something went wrong';
            eventInstance.MessageField__c = response != null && response.data != null && !response.data.isEmpty() ? response.data[0] : 'Error on code or webservice!';
        }else{
            if (response200 != null ) {
                eventInstance.Message__c = response200.message;
                eventInstance.isUpdate__c = false;
                if(methodType == 'Update'){
                    eventInstance.isUpdate__c = true;
                }
                order.LastIntegrationDateTime__c = System.now();
                order.LastIntegrationDescription__c = response200.message;
                order.iFrame__c = response200.data.iframe_elba;
            } 
        }
        

        EventBus.publish(eventInstance);
    }

    /**
     * @description Builds the JSON request body map from Order and related record fields
     * @param order The Order record containing the data to map
     * @return Map of field keys to values for the API request body
     */
    private static Map<String, Object> buildRequestBody(Order order) {
        String address = buildAddress(order);
        return new Map<String, Object>{
            'company_name' => String.isEmpty(String.valueOf(order.CaseNumber__r.GrandAccount__c)) ? '' : order.CaseNumber__r.GrandAccount__c,
            'initial_coverage' => String.isEmpty(String.valueOf(order.CaseNumber__r.GrandAccount__c)) ? '' : order.CaseNumber__r.GrandAccount__c,
            'order_number' => String.isEmpty(String.valueOf(order.OrderNumber)) ? '' : order.OrderNumber,
            'case_number' => String.isEmpty(String.valueOf(order.CaseNumber__r.CaseNumber)) ? '' : order.CaseNumber__r.CaseNumber,
            'company_charge_number' => String.isEmpty(String.valueOf(order.CaseNumber__r.GCOrderNumber__c)) ? '' : order.CaseNumber__r.GCOrderNumber__c,
            'order_id' => String.isEmpty(String.valueOf(order.Id)) ? '' : order.Id,
            'case_id' => String.isEmpty(String.valueOf(order.CaseNumber__c)) ? '' : order.CaseNumber__c,
            'provider_tax_number' => String.isEmpty(String.valueOf(order.Account.TaxNumber__c)) ? '' : order.Account.TaxNumber__c,
            'provider_email' => String.isEmpty(String.valueOf(order.Account.Email__c)) ? '' : order.Account.Email__c,
            'provider_name' => String.isEmpty(String.valueOf(order.Account.Name)) ? '' : order.Account.Name,
            'provider_phone' => String.isEmpty(String.valueOf(order.Account.Phone)) ? '' : order.Account.Phone,
            'provider_phone_number' => String.isEmpty(String.valueOf(order.Account.Phone)) ? '' : order.Account.Phone,
            'insurance_company' => String.isEmpty(String.valueOf(order.CaseNumber__r.GrandAccount__c)) ? '' : order.CaseNumber__r.GrandAccount__c,
            'urgent' => toBinaryValue(order.Urgent__c),
            'sinister_date' => order.CaseNumber__r.ClaimDate__c,
            //'category' => String.isEmpty(String.valueOf(order.category)) ? '' : order.category,
            'postal_code' => String.isEmpty(String.valueOf(order.BillToContact.MailingPostalCode)) ? '' : order.BillToContact.MailingPostalCode,
            'address' => address,
            'city' => String.isEmpty(String.valueOf(order.BillToContact.MailingCity)) ? '' : order.BillToContact.MailingCity,
            'district' => String.isEmpty(String.valueOf(order.BillToContact.MailingState)) ? '' : order.BillToContact.MailingState,
            'initial_coverage' => String.isEmpty(String.valueOf(order.CaseNumber__r.Coverage__c)) ? '' : order.CaseNumber__r.Coverage__c,
            'insured_name' => String.isEmpty(String.valueOf(order.BillToContact.Name)) ? '' : order.BillToContact.Name,
            'insured_identification' => String.isEmpty(String.valueOf(order.BillToContact.IDNumber__c)) ? '' : order.BillToContact.IDNumber__c,
            'policy_phone_number' => String.isEmpty(String.valueOf(order.BillToContact.Phone)) ? '' : order.BillToContact.Phone,
            'phone_number' => String.isEmpty(String.valueOf(order.BillToContact.Phone)) ? '' : order.BillToContact.Phone,
            'observations' => String.isEmpty(String.valueOf(order.CaseNumber__r.Description)) ? '' : order.CaseNumber__r.Description,
            'typology' => String.isEmpty(String.valueOf(order.Type)) ? '' : order.Type,
            'policy_number' => String.isEmpty(String.valueOf(order.BillToContact.PolicyNumber__c)) ? null : String.valueOf(order.BillToContact.PolicyNumber__c),
            'telephone_number' => String.isEmpty(String.valueOf(order.BillToContact.MobilePhone)) ? '' : order.BillToContact.MobilePhone,
            'insured_tax_number' => String.isEmpty(String.valueOf(order.BillToContact.IDNumber__c)) ? '' : order.BillToContact.IDNumber__c,
            'contact_person' => String.isEmpty(String.valueOf(order.BillToContact.Name)) ? '' : order.BillToContact.Name,
            'contact_relation' => String.isEmpty(String.valueOf(order.CaseNumber__r.RelationshiptotheInsured__c)) ? '' : order.CaseNumber__r.RelationshiptotheInsured__c,
            'contact_phone_number' => String.isEmpty(String.valueOf(order.BillToContact.MobilePhone)) ? '' : order.BillToContact.MobilePhone,
            'contact_email_address' => String.isEmpty(String.valueOf(order.BillToContact.Email)) ? '' : order.BillToContact.Email,
            'contact_telephone_number' => String.isEmpty(String.valueOf(order.BillToContact.Phone)) ? '' : order.BillToContact.Phone,
            'occurrence_date' => order.CaseNumber__r.ClaimDate__c,
            'description' => String.isEmpty(String.valueOf(order.CaseNumber__r.Description)) ? '' : order.CaseNumber__r.Description,
            'coverage' => String.isEmpty(String.valueOf(order.CaseNumber__r.Coverage__c)) ? '' : order.CaseNumber__r.Coverage__c,
            'assigned_job' => String.isEmpty(String.valueOf(order.Guild__c)) ? '' : order.Guild__c,
            'operator_name' => String.isEmpty(String.valueOf(order.CaseNumber__r.ClaimsHandlerName__c)) ? '' : order.CaseNumber__r.ClaimsHandlerName__c,
            'operator_email_address' => String.isEmpty(String.valueOf(order.CaseNumber__r.ClaimsHandlerEmail__c)) ? '' : order.CaseNumber__r.ClaimsHandlerEmail__c,
            'product_code' => String.isEmpty(String.valueOf(order.BillToContact.LineOfBusiness__c)) ? '' : order.BillToContact.LineOfBusiness__c,
            'declaration_date' => order.CaseNumber__r.ParticipationDate__c,
            'policy_effective_date' => order.BillToContact.PolicyStartDate__c,
            // 'service_near_policy' => String.isBlank(order.CaseNumber__r.SCC__c) ? 0 : 1,
            'high_frequency' => hasMarker(order.CaseNumber__r.Marcadores__c, 'M0036') ? 1 : 0,
            //'anti_corrosion' => toBinaryValue(order.CaseNumber__r.CorrosionPresent__c),
            'vts_opf_protection' => toBinaryValue(order.OPFVTSIndicatorsPresent__c),
            'vip_client' => toBinaryValue(order.BillToContact.IsVIP__c),
            /* 'elba_capital_efificio' => String.isEmpty(String.valueOf(order.BillToContact.BuildingCapital__c)) ? null : Integer.valueOf(String.valueOf(order.BillToContact.BuildingCapital__c).replace(',', '')),
            'elba_capital_responsabilidade_civil' => String.isEmpty(String.valueOf(order.BillToContact.LiabilityCapital__c)) ? null : Integer.valueOf(String.valueOf(order.BillToContact.LiabilityCapital__c).replace(',', '')),
            'elba_capital_recheio' => String.isEmpty(String.valueOf(order.BillToContact.FillingCapital__c)) ? '' : String.valueOf(order.BillToContact.FillingCapital__c).replace(',', ''), */
            'insured_email' => String.isEmpty(String.valueOf(order.BillToContact.Email)) ? '' : order.BillToContact.Email,
           
            'position_portal' => 'datos_encargos'
        };
    }

    /**
     * @description Builds a concatenated address string from the Order BillToContact mailing fields
     * @param order The Order record containing the BillToContact address fields
     * @return Concatenated address string
     */
    private static String buildAddress(Order order) {
        if (order == null || order.BillToContact == null) {
            return '';
        }

        String address = '';
        if (order.BillToContact.MailingStreet != null) {
            address += order.BillToContact.MailingStreet;
        }
        if (order.BillToContact.MailingCity != null) {
            if (!String.isBlank(address)) address += ' ';
            address += order.BillToContact.MailingCity;
        }
        if (order.BillToContact.MailingPostalCode != null) {
            if (!String.isBlank(address)) address += ' ';
            address += order.BillToContact.MailingPostalCode;
        }
        if (order.BillToContact.MailingState != null) {
            if (!String.isBlank(address)) address += ' ';
            address += order.BillToContact.MailingState;
        }
        if (order.BillToContact.MailingCountry != null) {
            if (!String.isBlank(address)) address += ' ';
            address += order.BillToContact.MailingCountry;
        }

        return address;
    }

    /**
     * @description Collects all missing mandatory field keys from an Order and its related records.
     *             Only checks fields that are Mandatory per the POST /api/services spec.
     * @param order The Order record to inspect
     * @return List of missing mandatory field key names
     */
    private static List<String> collectMissingMandatoryFields(Order order) {
        List<String> missingFields = new List<String>();

        // Provider mandatory fields
        addMissingFieldIfBlank(missingFields, 'providerName', order.Account != null ? order.Account.Name : null);
        addMissingFieldIfBlank(missingFields, 'providerTaxNumber', order.Account != null ? order.Account.TaxNumber__c : null);
        addMissingFieldIfBlank(missingFields, 'providerEmail', order.Account != null ? order.Account.Email__c : null);

        // Order mandatory fields
        addMissingFieldIfBlank(missingFields, 'orderNumber', order.OrderNumber);
        addMissingFieldIfBlank(missingFields, 'caseNumber', order.CaseNumber__r != null ? order.CaseNumber__r.CaseNumber : null);
        addMissingFieldIfBlank(missingFields, 'policyNumber', order.BillToContact != null ? order.BillToContact.PolicyNumber__c : null);
        addMissingFieldIfBlank(missingFields, 'insuranceCompany', order.CaseNumber__r != null ? order.CaseNumber__r.GrandAccount__c : null);

        // Insured mandatory fields
        addMissingFieldIfBlank(missingFields, 'insuredName', order.BillToContact != null ? order.BillToContact.Name : null);
        addMissingFieldIfBlank(missingFields, 'insuredIdentification', order.BillToContact != null ? order.BillToContact.IDNumber__c : null);
        addMissingFieldIfBlank(missingFields, 'policyPhoneNumber', order.BillToContact != null ? order.BillToContact.MobilePhone : null);

        // Address mandatory fields
        addMissingFieldIfBlank(missingFields, 'address', buildAddress(order));
        addMissingFieldIfBlank(missingFields, 'postalCode', order.BillToContact != null ? order.BillToContact.MailingPostalCode : null);
        addMissingFieldIfBlank(missingFields, 'city', order.BillToContact != null ? order.BillToContact.MailingCity : null);
        addMissingFieldIfBlank(missingFields, 'district', order.BillToContact != null ? order.BillToContact.MailingState : null);

        // Contact mandatory fields
        addMissingFieldIfBlank(missingFields, 'contactPerson', order.BillToContact != null ? order.BillToContact.Name : null);
        addMissingFieldIfBlank(missingFields, 'contactTelephoneNumber', order.BillToContact != null ? order.BillToContact.MobilePhone : null);

        // Date mandatory fields
        addMissingFieldIfBlank(missingFields, 'sinisterDate', order.CaseNumber__r != null ? order.CaseNumber__r.ClaimDate__c : null);

        // Service coverages: at least one required
        if (order.CaseNumber__c != null) {
            Integer coverageCount = [SELECT COUNT() FROM InsurableCoverage__c WHERE Claim__c = :order.CaseNumber__c];
            if (coverageCount == 0) {
                missingFields.add('serviceCoverages');
            }
        } else {
            missingFields.add('serviceCoverages');
        }

        addMissingStakeholderFieldsIfAny(missingFields, order);

        return missingFields;
    }

    /**
     * @description Validates stakeholder records related to the Order and adds missing field keys to the list
     * @param missingFields The list to append missing field keys to
     * @param order The Order record whose related stakeholders will be validated
     */
    private static void addMissingStakeholderFieldsIfAny(List<String> missingFields, Order order) {
        if (order == null || order.CaseNumber__c == null) {
            return;
        }

        List<Stakeholders__c> stakeholders = [
            SELECT Name, StakeholderType__c, Phone__c, StakeholderTaxID__c,
                   Address__Street__s, Address__City__s, Address__PostalCode__s
            FROM Stakeholders__c
            WHERE Case__c = :order.CaseNumber__c
        ];

        // Stakeholders are optional. Only validate if at least one exists.
        if (stakeholders.isEmpty()) {
            return;
        }

        for (Stakeholders__c s : stakeholders) {
            if (String.isBlank(s.Name)) {
                addUniqueMissingField(missingFields, 'stakeholderName');
            }

            if (String.isBlank(s.StakeholderType__c) || !VALID_STAKEHOLDER_TYPES.contains(s.StakeholderType__c)) {
                addUniqueMissingField(missingFields, 'stakeholderType');
            }

            if (String.isBlank(s.StakeholderTaxID__c)) {
                addUniqueMissingField(missingFields, 'stakeholderTaxNumber');
            }

            if (String.isBlank(s.Phone__c)) {
                addUniqueMissingField(missingFields, 'stakeholderPhoneNumber');
            }

            String stakeholderAddress = buildStakeholderAddress(s);
            if (String.isBlank(stakeholderAddress)) {
                addUniqueMissingField(missingFields, 'stakeholderAddress');
            }
        }
    }

    /**
     * @description Builds a concatenated address string from a Stakeholder address fields
     * @param stakeholder The Stakeholder record containing address fields
     * @return Concatenated address string
     */
    private static String buildStakeholderAddress(Stakeholders__c stakeholder) {
        if (stakeholder == null) {
            return '';
        }

        List<String> parts = new List<String>();
        if (String.isNotBlank(stakeholder.Address__Street__s)) parts.add(stakeholder.Address__Street__s);
        if (String.isNotBlank(stakeholder.Address__City__s)) parts.add(stakeholder.Address__City__s);
        if (String.isNotBlank(stakeholder.Address__PostalCode__s)) parts.add(stakeholder.Address__PostalCode__s);

        return parts.isEmpty() ? '' : String.join(parts, ' ');
    }

    /**
     * @description Adds a field key to the missing fields list only if it is not already present
     * @param missingFields The list of missing field keys
     * @param fieldKey The field key to add
     */
    private static void addUniqueMissingField(List<String> missingFields, String fieldKey) {
        if (missingFields == null || String.isBlank(fieldKey)) {
            return;
        }

        if (!missingFields.contains(fieldKey)) {
            missingFields.add(fieldKey);
        }
    }

    /**
     * @description Adds a field key to the missing fields list if the value is null or blank
     * @param missingFields The list of missing field keys
     * @param fieldKey The field key to add
     * @param value The field value to check
     */
    private static void addMissingFieldIfBlank(List<String> missingFields, String fieldKey, Object value) {
        if (value == null) {
            missingFields.add(fieldKey);
            return;
        }

        if (value instanceof String && String.isBlank((String) value)) {
            missingFields.add(fieldKey);
        }
    }

    /**
     * @description Converts a Boolean value to its binary integer representation
     * @param value The Boolean value to convert
     * @return 1 if true, 0 otherwise
     */
    private static Integer toBinaryValue(Boolean value) {
        return value == true ? 1 : 0;
    }

    /**
     * @description Checks whether a semicolon-separated markers string contains the specified marker code
     * @param markers Semicolon-separated string of marker codes
     * @param markerCode The marker code to search for
     * @return True if the marker code is found, false otherwise
     */
    private static Boolean hasMarker(String markers, String markerCode) {
        if (String.isBlank(markers) || String.isBlank(markerCode)) {
            return false;
        }

        List<String> values = markers.split(';');
        for (String value : values) {
            if (value != null && value.trim() == markerCode) {
                return true;
            }
        }

        return false;
    }

    public class ServiceResponse {
        public ResponseInfo info;
        public String message;
        public List<String> data;
    }

    public class ResponseInfo {
        public String iframe_elba;
        public String message;
    }


    public class response200{
        public string message;
        public data200 data;
    }
    public class data200{
        public string iframe_elba;
    }
}