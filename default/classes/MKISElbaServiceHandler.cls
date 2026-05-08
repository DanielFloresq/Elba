/**
 * @description       : Handles Create Service and Update Service calls to MKIS ELBA API.
 *                      Triggered from Order insert (Create) and Order update (Update).
 * @author            : Daniel Flores
 * @group             : MKIS Integration
 * @last modified on  : 07-05-2026
 * @last modified by  : Daniel Flores
**/
public without sharing class MKISElbaServiceHandler {

    private static final String ENDPOINT_SERVICES = '/services';
    private static final String ACCOUNT_INFO_TYPE_EMAIL = 'Email';
    private static final String ACCOUNT_INFO_TYPE_PHONE = 'Phone';
    private static final String SUPPLIER_RECORD_TYPE = 'Supplier';
    private static final String NON_SUPPLIER_ACCOUNT_MESSAGE = 'Solo es posible enviar el cargo a MKIS cuando la cuenta relacionada es la de un proveedor.';

    /**
    * @description Creates a service in MKIS ELBA when an Order is created.
    * @param orderIds List of Order Ids to process
    **/
    @future(callout=true)
    public static void createServiceAsync(List<Id> orderIds) {
        List<Order> orders = queryOrders(orderIds);
        List<Order> supplierOrders = new List<Order>();
        for (Order ord : orders) {
            if (!isSupplierOrder(ord)) {
                handleNonSupplierOrder(ord, 'MKISElbaServiceHandler/createService');
                continue;
            }
            supplierOrders.add(ord);
        }

        Map<Id, List<AccountInformation__c>> accountInfoByAccountId = queryAccountInformationByAccountIds(getAccountIds(supplierOrders));

        // === PHASE 1: ALL CALLOUTS — no DML before this block ===
        Map<Id, HttpResponse> responseByOrderId = new Map<Id, HttpResponse>();
        List<Id> successOrderIds = new List<Id>();

        for (Order ord : supplierOrders) {
            try {
                MKISElbaStructures.CreateServiceRequest req = buildCreateServiceRequest(ord, accountInfoByAccountId);
                String body = JSON.serialize(req, true);
                HttpResponse res = MKISElbaCalloutService.doPost(ENDPOINT_SERVICES, body);
                responseByOrderId.put(ord.Id, res);
                if (res.getStatusCode() == 200) {
                    ord.UrlLinkStatus__c = true;
                    successOrderIds.add(ord.Id);
                }
            } catch (Exception e) {
                System.debug('MKIS createService callout error: ' + e.getMessage());
            }
        }

        // Interventions callouts — still in callout phase, DML comes after
        if (!successOrderIds.isEmpty()) {
            MKISElbaInterventionHandler.createInterventionsForOrders(successOrderIds);
        }

        // === PHASE 2: ALL DML ===
        for (Order ord : supplierOrders) {
            HttpResponse res = responseByOrderId.get(ord.Id);
            if (res == null) continue;
            Boolean success = res.getStatusCode() == 200;
            if (success) {
                saveMkisIdsFromServiceResponse(res.getBody());
            }
            logIntegration(ord.Id, res, 'MKISElbaServiceHandler/createService');
            sendResponseEvent(ord.Id, success, parseApiMessage(res.getBody()));
        }
        if (!supplierOrders.isEmpty()) {
            update supplierOrders;
        }
    }

    /**
    * @description Creates a service in MKIS ELBA from the "Enviar a Urlink" button.
    * @param orderId The Order record Id
    * @return Integration result message
    **/
    @AuraEnabled
    public static Map<String, Object> createServiceFromButton(Id orderId) {
        List<Order> orders = queryOrders(new List<Id>{ orderId });
        if (orders.isEmpty()) {
            throw new AuraHandledException('Order not found.');
        }

        if (!isSupplierOrder(orders[0])) {
            logError(orders[0].Id, NON_SUPPLIER_ACCOUNT_MESSAGE, 'MKISElbaServiceHandler/createService');
            return new Map<String, Object>{
                'success' => false,
                'statusCode' => 400,
                'message' => NON_SUPPLIER_ACCOUNT_MESSAGE
            };
        }

        Map<Id, List<AccountInformation__c>> accountInfoByAccountId = queryAccountInformationByAccountIds(getAccountIds(orders));
        MKISElbaStructures.CreateServiceRequest req = buildCreateServiceRequest(orders[0], accountInfoByAccountId);
        String body = JSON.serialize(req, true);

        try {
            HttpResponse res = MKISElbaCalloutService.doPost(ENDPOINT_SERVICES, body);
            System.debug(res.getBody());
            Integer statusCode = res.getStatusCode();
            String apiMessage = parseApiMessage(res.getBody());

            if (statusCode == 200) {
                // Interventions callout BEFORE any DML
                MKISElbaInterventionHandler.createInterventionsForOrders(new List<Id>{ orders[0].Id });
            }

            // All DML after all callouts
            logIntegration(orders[0].Id, res, 'MKISElbaServiceHandler/createService');
            if (statusCode == 200) {
                Order updateOrder = new Order(Id = orders[0].Id, UrlLinkStatus__c = true);
                update updateOrder;
                saveMkisIdsFromServiceResponse(res.getBody());
            }

            return new Map<String, Object>{
                'success' => statusCode == 200,
                'statusCode' => statusCode,
                'message' => apiMessage
            };
        } catch (Exception e) {
            logError(orders[0].Id, e.getMessage(), 'MKISElbaServiceHandler/createService');
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
    * @description Creates a service in MKIS ELBA for a single Order.
    * @param ord The Order record
    **/
    public static void createService(Order ord) {
        if (!isSupplierOrder(ord)) {
            handleNonSupplierOrder(ord, 'MKISElbaServiceHandler/createService');
            return;
        }
        createService(ord, queryAccountInformationByAccountIds(new Set<Id>{ ord.AccountId }));
    }

    /**
    * @description Creates a service in MKIS ELBA for a single Order using pre-queried account information.
    * @param ord The Order record
    * @param accountInfoByAccountId Map of Account Id to AccountInformation__c records
    **/
    private static Boolean createService(Order ord, Map<Id, List<AccountInformation__c>> accountInfoByAccountId) {
        MKISElbaStructures.CreateServiceRequest req = buildCreateServiceRequest(ord, accountInfoByAccountId);
        String body = JSON.serialize(req, true);

        try {
            HttpResponse res = MKISElbaCalloutService.doPost(ENDPOINT_SERVICES, body);
            Boolean success = res.getStatusCode() == 200;
            if (success) {
                ord.UrlLinkStatus__c = true;
                saveMkisIdsFromServiceResponse(res.getBody());
            }
            logIntegration(ord.Id, res, 'MKISElbaServiceHandler/createService');
            sendResponseEvent(ord.Id, success, parseApiMessage(res.getBody()));
            return success;
        } catch (Exception e) {
            logError(ord.Id, e.getMessage(), 'MKISElbaServiceHandler/createService');
            sendResponseEvent(ord.Id, false, e.getMessage());
            return false;
        }
    }

    /**
    * @description Updates a service in MKIS ELBA when an Order is updated.
    * @param orderIds List of Order Ids to process
    **/
    @future(callout=true)
    public static void updateServiceAsync(List<Id> orderIds) {
        List<Order> orders = queryOrders(orderIds);
        List<Order> supplierOrders = new List<Order>();
        for (Order ord : orders) {
            if (!isSupplierOrder(ord)) {
                handleNonSupplierOrder(ord, 'MKISElbaServiceHandler/updateService');
                continue;
            }
            supplierOrders.add(ord);
        }
        for (Order ord : supplierOrders) {
            updateService(ord);
        }
    }

    /**
    * @description Updates a service in MKIS ELBA for a single Order.
    * @param ord The Order record
    **/
    public static void updateService(Order ord) {
        if (!isSupplierOrder(ord)) {
            handleNonSupplierOrder(ord, 'MKISElbaServiceHandler/updateService');
            return;
        }

        MKISElbaStructures.UpdateServiceRequest req = buildUpdateServiceRequest(ord);
        String body = JSON.serialize(req, true);
        System.debug(body);
        try {
            HttpResponse res = MKISElbaCalloutService.doPut(ENDPOINT_SERVICES, body);
            System.debug(res.getBody());
            logIntegration(ord.Id, res, 'MKISElbaServiceHandler/updateService');
            sendResponseEvent(ord.Id, res.getStatusCode() == 200, parseApiMessage(res.getBody()));
        } catch (Exception e) {
            logError(ord.Id, e.getMessage(), 'MKISElbaServiceHandler/updateService');
            sendResponseEvent(ord.Id, false, e.getMessage());
        }
    }

    /**
    * @description Builds the Create Service request from an Order record.
    **/
    private static MKISElbaStructures.CreateServiceRequest buildCreateServiceRequest(
        Order ord,
        Map<Id, List<AccountInformation__c>> accountInfoByAccountId
    ) {
        MKISElbaStructures.CreateServiceRequest req = new MKISElbaStructures.CreateServiceRequest();
        List<AccountInformation__c> providerAccountInfo = accountInfoByAccountId.get(ord.AccountId);

        // Provider (nested object - mandatory)
        MKISElbaStructures.Provider prov = new MKISElbaStructures.Provider();
        prov.name = ord.Account != null ? ord.Account.Name : null;
        prov.tax_number = ord.Account != null ? ord.Account.SAPEntityCode__c : null;
        prov.email = getEmailAccountInformation(providerAccountInfo);
        prov.phone_number = getOperatorPhoneAccountInformation(providerAccountInfo);
        prov.categories = String.valueOf(ord.Account.Guild__c).split(';');
        prov.autonomy = ord.Account != null && ord.Account.RepairAutonomy__c != null ? ord.Account.RepairAutonomy__c : null;
        prov.reduced_vat = ord.Account != null && ord.Account.ReducedVAT__c != null ? ord.Account.ReducedVAT__c ? 1 : 0 : null;
        prov.vat_value = ord.Account != null && ord.Account.VAT__c != null ? ord.Account.VAT__c : null;
        prov.reduced_vat_value = ord.Account != null && ord.Account.ReducedVATValue__c != null ? ord.Account.ReducedVATValue__c : null;
        req.provider = prov;

        // Order identifiers (mandatory)
        req.order_id = String.valueOf(ord.Id);
        req.order_number = ord.OrderNumber;
        req.case_id = ord.CaseNumber__c != null ? String.valueOf(ord.CaseNumber__c) : null;
        req.case_number = ord.CaseNumber__r != null ? ord.CaseNumber__r.CaseNumber : null;
        req.insurance_company = ord.CaseNumber__r != null ? ord.CaseNumber__r.GrandAccount__c : null;
        req.associated_service_order_id = ord.RelatedOrder__c != null ? String.valueOf(ord.RelatedOrder__c) : null;

        // Policy / insured fields (mandatory)
        req.policy_number = ord.BillToContact != null ? ord.BillToContact.PolicyNumber__c : null;
        req.urgent = ord.Urgent__c != null && ord.Urgent__c ? 1 : 0;
        req.insured_name = ord.BillToContact != null ? ord.BillToContact.Name : null;
        req.insured_identification = ord.BillToContact != null ? ord.BillToContact.IDNumber__c : null;
        req.policy_phone_number = ord.BillToContact != null ? ord.BillToContact.MobilePhone : null;

        // Address (mandatory)
        req.address = buildAddress(ord);
        req.postal_code = ord.BillToContact != null ? ord.BillToContact.MailingPostalCode : null;
        req.city = ord.BillToContact != null ? ord.BillToContact.MailingCity : null;
        req.district = ord.BillToContact != null ? ord.BillToContact.MailingState : null;

        // Contact (contact_person + contact_telephone_number mandatory, rest optional)
        req.contact_person = ord.BillToContact != null ? ord.BillToContact.Name : null;
        req.contact_telephone_number = ord.BillToContact != null ? ord.BillToContact.MobilePhone : null;
        req.contact_relation = ord.CaseNumber__r != null ? ord.CaseNumber__r.RelationshiptotheInsured__c : null;
        req.contact_phone_number = ord.BillToContact != null ? ord.BillToContact.Phone : null;
        req.contact_email_address = ord.BillToContact != null ? ord.BillToContact.Email : null;

        // Dates
        req.sinister_date = ord.CaseNumber__r != null && ord.CaseNumber__r.ClaimDate__c != null
            ? String.valueOf(ord.CaseNumber__r.ClaimDate__c) : null;
        req.occurrence_date = req.sinister_date;
        req.declaration_date = ord.CaseNumber__r != null && ord.CaseNumber__r.ParticipationDate__c != null
            ? String.valueOf(ord.CaseNumber__r.ParticipationDate__c) : null;
        req.policy_effective_date = ord.BillToContact != null && ord.BillToContact.PolicyStartDate__c != null
            ? String.valueOf(ord.BillToContact.PolicyStartDate__c) : null;

        // Optional details
        req.observations = ord.Observaciones__c;
        req.cause = ord.Reason__c;
        req.subcause = ord.SubReason__c;
        req.description = ord.CaseNumber__r != null ? ord.CaseNumber__r.Description : null;
        req.coverage = ord.CaseNumber__r != null ? ord.CaseNumber__r.Coverage__c : null;
        req.assigned_job = ord.Guild__c;
        req.operator_name = ord.CaseNumber__r != null ? ord.CaseNumber__r.ClaimsHandlerName__c : null;
        req.operator_email_address = ord.CaseNumber__r != null ? ord.CaseNumber__r.ClaimsHandlerEmail__c : null;
        /* req.product_code = ord.BillToContact != null ? ord.BillToContact.LineOfBusiness__c : null; */

        // Capital limits (optional)
        req.cte_capital_limit = ord.BillToContact != null ? ord.BillToContact.BuildingCapital__c : null;
        req.cdo_capital_limit = ord.BillToContact != null ? ord.BillToContact.FillingCapital__c : null;
        req.rc_capital_limit = ord.BillToContact != null ? ord.BillToContact.LiabilityCapital__c : null;

        // Integer flags (optional)
        req.vts_opf_protection = (ord.OPFVTSIndicatorsPresent__c != null && ord.OPFVTSIndicatorsPresent__c) ? 1 : 0;
        req.vip_client = (ord.BillToContact != null && ord.BillToContact.IsVIP__c != null && ord.BillToContact.IsVIP__c) ? 1 : 0;
        req.high_frequency = (ord.CaseNumber__r != null && String.isNotBlank(ord.CaseNumber__r.Marcadores__c)
            && ord.CaseNumber__r.Marcadores__c.contains('M0036')) ? 1 : 0;
        req.anti_corrosion = (ord.CaseNumber__r != null && ord.CaseNumber__r.AntiCorrosion__c != null && ord.CaseNumber__r.AntiCorrosion__c) ? 1 : 0;
        req.low_expiration = (ord.CaseNumber__r != null && ord.CaseNumber__r.LowExpiration__c != null && ord.CaseNumber__r.LowExpiration__c) ? 1 : 0;
        req.service_near_policy = (ord.CaseNumber__r != null && ord.CaseNumber__r.ServiceNearPolicy__c != null && ord.CaseNumber__r.ServiceNearPolicy__c) ? 1 : 0;

        // Damage / warranty / coverage extras (optional)
        req.warranty = ord.Coverage__c;
        req.damage = ord.CaseNumber__r != null ? ord.CaseNumber__r.DamagesIncurred__c : null;
        req.cte_aesthetic_capital_limit = ord.CaseNumber__r != null ? ord.CaseNumber__r.CTEAestheticCapitalLimit__c : null;
        req.cdo_aesthetic_capital_limit = ord.CaseNumber__r != null ? ord.CaseNumber__r.CDOAestheticCapitalLimit__c : null;

        // Visit fields (optional)
        req.visit = (ord.VisitCompleted__c != null && ord.VisitCompleted__c) ? 1 : 0;
        req.failed_visit_reason = ord.VisitNotCompletedReason__c;
        req.visit_at = ord.VisitDateTime__c != null ? String.valueOf(ord.VisitDateTime__c) : null;
        req.visit_type = ord.VisitType__c;
        req.worker_description = ord.OperatorDescription__c;

        // Damage assessment flags (optional)
        req.origin_located = ord.OriginIdentification__c;
        req.damage_before_policy_inception = (ord.DamagePriortoPolicyInception__c != null && ord.DamagePriortoPolicyInception__c) ? 1 : 0;
        req.damage_before_occurrence_date = (ord.DamagePriortoDateofOccurrence__c != null && ord.DamagePriortoDateofOccurrence__c) ? 1 : 0;
        req.opf_vts_indicators = (ord.OPFVTSIndicatorsPresent__c != null && ord.OPFVTSIndicatorsPresent__c) ? 1 : 0;
        req.continuous_damage_over_time = (ord.OngoingDamage__c != null && ord.OngoingDamage__c) ? 1 : 0;
        req.damage_due_to_lack_of_maintenance = (ord.DamageDuetoLackofMaintenance__c != null && ord.DamageDuetoLackofMaintenance__c) ? 1 : 0;
        req.has_coverage = (ord.ClaimCoverage__c != null && ord.ClaimCoverage__c) ? 1 : 0;
        req.refused = (ord.Rejection__c != null && ord.Rejection__c) ? 1 : 0;
        req.worker_appreciation = ord.OperatorAssessment__c;
        req.meets_tax_condition = (ord.MeetsVATConditions__c != null && ord.MeetsVATConditions__c) ? 1 : 0;
        req.damage_origin_located = ord.InitialDamagesLocated__c == 'Yes' ? 1 : 0;
        req.damage_origin_repaired = ord.InitialDamagesRepaired__c == 'Yes' ? 1 : 0;
        req.non_repair_reason = ord.NoRepairReason__c;
        req.requires_expert_intervention = (ord.AdjusterInterventionRequired__c != null && ord.AdjusterInterventionRequired__c) ? 1 : 0;
        req.expert_intervention_reason = ord.ReasonforAdjusterIntervention__c;
        req.total = ord.TotalBudgetAmount__c;
        req.service_coverages = buildServiceCoverages(ord.CaseNumber__c);
        req.stakeholders = buildStakeholders(ord.Id);
        System.debug(JSON.serialize(req, true));
        return req;
    }

    /**
    * @description Builds the Update Service request from an Order record.
    **/
    private static MKISElbaStructures.UpdateServiceRequest buildUpdateServiceRequest(Order ord) {
        MKISElbaStructures.UpdateServiceRequest req = new MKISElbaStructures.UpdateServiceRequest();

        // Order identifiers
        req.order_id           = String.valueOf(ord.Id);
        req.order_number       = ord.OrderNumber;
        req.case_id            = ord.CaseNumber__c != null ? String.valueOf(ord.CaseNumber__c) : null;
        req.case_number        = ord.CaseNumber__r != null ? ord.CaseNumber__r.CaseNumber : null;
        req.insurance_company  = ord.CaseNumber__r != null ? ord.CaseNumber__r.GrandAccount__c : null;

        // Policy / insured (from BillToContact)
        req.policy_number          = ord.BillToContact != null ? ord.BillToContact.PolicyNumber__c : null;
        req.urgent                 = ord.Urgent__c != null && ord.Urgent__c ? 1 : 0;
        req.insured_name           = ord.BillToContact != null ? ord.BillToContact.Name : null;
        req.insured_identification = ord.BillToContact != null ? ord.BillToContact.IDNumber__c : null;
        req.policy_phone_number    = ord.BillToContact != null ? ord.BillToContact.MobilePhone : null;

        // Address
        req.address     = buildAddress(ord);
        req.postal_code = ord.BillToContact != null ? ord.BillToContact.MailingPostalCode : null;
        req.city        = ord.BillToContact != null ? ord.BillToContact.MailingCity : null;
        req.district    = ord.BillToContact != null ? ord.BillToContact.MailingState : null;

        // Contact
        req.contact_person       = ord.BillToContact != null ? ord.BillToContact.Name : null;
        req.contact_relation     = ord.CaseNumber__r != null ? ord.CaseNumber__r.RelationshiptotheInsured__c : null;
        req.contact_phone_number = ord.BillToContact != null ? ord.BillToContact.Phone : null;
        req.contact_observations = null;

        // Dates
        req.sinister_date         = ord.CaseNumber__r != null && ord.CaseNumber__r.ClaimDate__c != null
            ? String.valueOf(ord.CaseNumber__r.ClaimDate__c) : null;
        req.occurrence_date       = req.sinister_date;
        req.declaration_date      = ord.CaseNumber__r != null && ord.CaseNumber__r.ParticipationDate__c != null
            ? String.valueOf(ord.CaseNumber__r.ParticipationDate__c) : null;
        req.policy_effective_date = ord.BillToContact != null && ord.BillToContact.PolicyStartDate__c != null
            ? String.valueOf(ord.BillToContact.PolicyStartDate__c) : null;

        // Optional details
        req.observations           = ord.Observaciones__c;
        req.cause                  = ord.Reason__c;
        req.subcause               = ord.SubReason__c;
        req.description            = ord.CaseNumber__r != null ? ord.CaseNumber__r.Description : null;
        req.coverage               = ord.CaseNumber__r != null ? ord.CaseNumber__r.Coverage__c : null;
        req.assigned_job           = ord.Guild__c;
        req.operator_name          = ord.CaseNumber__r != null ? ord.CaseNumber__r.ClaimsHandlerName__c : null;
        req.operator_email_address = ord.CaseNumber__r != null ? ord.CaseNumber__r.ClaimsHandlerEmail__c : null;
        /* req.product_code           = ord.BillToContact != null ? ord.BillToContact.LineOfBusiness__c : null; */

        // Capital limits
        req.cte_capital_limit     = ord.BillToContact != null ? ord.BillToContact.BuildingCapital__c : null;
        req.cdo_capital_limit     = ord.BillToContact != null ? ord.BillToContact.FillingCapital__c : null;
        req.rc_capital_limit      = ord.BillToContact != null ? ord.BillToContact.LiabilityCapital__c : null;

        // Integer flags
        req.vts_opf_protection = (ord.OPFVTSIndicatorsPresent__c != null && ord.OPFVTSIndicatorsPresent__c) ? 1 : 0;
        req.vip_client         = (ord.BillToContact != null && ord.BillToContact.IsVIP__c != null && ord.BillToContact.IsVIP__c) ? 1 : 0;
        req.high_frequency     = (ord.CaseNumber__r != null && String.isNotBlank(ord.CaseNumber__r.Marcadores__c)
            && ord.CaseNumber__r.Marcadores__c.contains('M0036')) ? 1 : 0;
        req.anti_corrosion     = (ord.CaseNumber__r != null && ord.CaseNumber__r.AntiCorrosion__c != null && ord.CaseNumber__r.AntiCorrosion__c) ? 1 : 0;
        req.low_expiration     = (ord.CaseNumber__r != null && ord.CaseNumber__r.LowExpiration__c != null && ord.CaseNumber__r.LowExpiration__c) ? 1 : 0;
        req.service_near_policy = (ord.CaseNumber__r != null && ord.CaseNumber__r.ServiceNearPolicy__c != null && ord.CaseNumber__r.ServiceNearPolicy__c) ? 1 : 0;

        // Damage / warranty / coverage extras
        req.warranty                    = ord.Coverage__c;
        req.damage                      = ord.CaseNumber__r != null ? ord.CaseNumber__r.DamagesIncurred__c : null;
        req.cte_aesthetic_capital_limit = ord.CaseNumber__r != null ? ord.CaseNumber__r.CTEAestheticCapitalLimit__c : null;
        req.cdo_aesthetic_capital_limit = ord.CaseNumber__r != null ? ord.CaseNumber__r.CDOAestheticCapitalLimit__c : null;

        // Visit fields
        req.visit               = (ord.VisitCompleted__c != null && ord.VisitCompleted__c) ? 1 : 0;
        req.failed_visit_reason = ord.VisitNotCompletedReason__c;
        req.visit_at            = ord.VisitDateTime__c != null ? String.valueOf(ord.VisitDateTime__c) : null;
        req.visit_type          = ord.VisitType__c;
        req.worker_description  = ord.OperatorDescription__c;

        // Damage assessment flags
        req.origin_located                    = ord.OriginIdentification__c;
        req.damage_before_policy_inception    = (ord.DamagePriortoPolicyInception__c != null && ord.DamagePriortoPolicyInception__c) ? 1 : 0;
        req.damage_before_occurrence_date     = (ord.DamagePriortoDateofOccurrence__c != null && ord.DamagePriortoDateofOccurrence__c) ? 1 : 0;
        req.opf_vts_indicators                = (ord.OPFVTSIndicatorsPresent__c != null && ord.OPFVTSIndicatorsPresent__c) ? 1 : 0;
        req.continuous_damage_over_time       = (ord.OngoingDamage__c != null && ord.OngoingDamage__c) ? 1 : 0;
        req.damage_due_to_lack_of_maintenance = (ord.DamageDuetoLackofMaintenance__c != null && ord.DamageDuetoLackofMaintenance__c) ? 1 : 0;
        req.has_coverage                      = (ord.ClaimCoverage__c != null && ord.ClaimCoverage__c) ? 1 : 0;
        req.refused                           = (ord.Rejection__c != null && ord.Rejection__c) ? 1 : 0;
        req.worker_appreciation               = ord.OperatorAssessment__c;
        req.meets_tax_condition               = (ord.MeetsVATConditions__c != null && ord.MeetsVATConditions__c) ? 1 : 0;
        req.damage_origin_located             = ord.InitialDamagesLocated__c == 'Yes' ? 1 : 0;
        req.damage_origin_repaired            = ord.InitialDamagesRepaired__c == 'Yes' ? 1 : 0;
        req.non_repair_reason                 = ord.NoRepairReason__c;
        req.requires_expert_intervention      = (ord.AdjusterInterventionRequired__c != null && ord.AdjusterInterventionRequired__c) ? 1 : 0;
        req.expert_intervention_reason        = ord.ReasonforAdjusterIntervention__c;

        // Budget / totals
        req.total        = ord.TotalBudgetAmount__c;
        req.gross_total  = null; // TODO: confirmar campo Salesforce
        req.vat_total    = null; // TODO: confirmar campo Salesforce
        req.budget_state = null; // TODO: confirmar campo Salesforce

        System.debug(JSON.serialize(req, true));
        return req;
    }

    /**
    * @description Builds the address string from Order's BillToContact fields.
    **/
    private static String buildAddress(Order ord) {
        if (ord.BillToContact == null) return null;
        List<String> parts = new List<String>();
        if (String.isNotBlank(ord.BillToContact.MailingStreet)) parts.add(ord.BillToContact.MailingStreet);
        if (String.isNotBlank(ord.BillToContact.MailingCity)) parts.add(ord.BillToContact.MailingCity);
        if (String.isNotBlank(ord.BillToContact.MailingPostalCode)) parts.add(ord.BillToContact.MailingPostalCode);
        if (String.isNotBlank(ord.BillToContact.MailingState)) parts.add(ord.BillToContact.MailingState);
        if (String.isNotBlank(ord.BillToContact.MailingCountry)) parts.add(ord.BillToContact.MailingCountry);
        return parts.isEmpty() ? null : String.join(parts, ' ');
    }

    /**
    * @description Builds service coverage items from InsurableCoverage__c records related to the Case.
    * @param caseId The Case (Claim) Id to query coverages for
    * @return List of ServiceCoverageItem to embed in the Create Service request
    **/
    private static List<MKISElbaStructures.ServiceCoverageItem> buildServiceCoverages(Id caseId) {
        List<MKISElbaStructures.ServiceCoverageItem> items = new List<MKISElbaStructures.ServiceCoverageItem>();
        if (caseId == null) return items;

        for (InsurableCoverage__c cov : [
            SELECT Coverage__c, CoverageAmountLimit__c, DeductibleAmount__c, Name, Id
            FROM InsurableCoverage__c
            WHERE Claim__c = :caseId
        ]) {
            MKISElbaStructures.ServiceCoverageItem item = new MKISElbaStructures.ServiceCoverageItem();
            item.coverage = cov.Coverage__c ;
            item.warranty = cov.Name;
            item.limit_amount = cov.CoverageAmountLimit__c;
            item.deductible_amount = cov.DeductibleAmount__c;
            item.external_id = cov.Id;
            items.add(item);
        }
        return items;
    }

    /**
    * @description Builds stakeholder items from related Stakeholders__c records.
    **/
    private static List<MKISElbaStructures.StakeholderItem> buildStakeholders(Id orderId) {
        List<MKISElbaStructures.StakeholderItem> items = new List<MKISElbaStructures.StakeholderItem>();
        List<Order> orderWithCase = [SELECT CaseNumber__c FROM Order WHERE Id = :orderId LIMIT 1];
        if (orderWithCase.isEmpty() || orderWithCase[0].CaseNumber__c == null) return items;

        List<Stakeholders__c> stakeholders = [
            SELECT Name, StakeholderType__c, Phone__c, Id,
                   Address__Street__s, Address__City__s, Address__PostalCode__s, StakeholderTaxID__c,
                   UniqueIdentifier__c
            FROM Stakeholders__c
            WHERE Case__c = :orderWithCase[0].CaseNumber__c
        ];
/* TaxNumber__c */
        for (Stakeholders__c s : stakeholders) {
            MKISElbaStructures.StakeholderItem item = new MKISElbaStructures.StakeholderItem();
            item.name = s.Name;
            item.stakeholder_type = s.StakeholderType__c;
            item.tax_number = s.StakeholderTaxID__c;
            item.phone_number = s.Phone__c;
            List<String> addrParts = new List<String>();
            if (String.isNotBlank(s.Address__Street__s)) addrParts.add(s.Address__Street__s);
            if (String.isNotBlank(s.Address__City__s)) addrParts.add(s.Address__City__s);
            if (String.isNotBlank(s.Address__PostalCode__s)) addrParts.add(s.Address__PostalCode__s);
            item.address = addrParts.isEmpty() ? null : String.join(addrParts, ' ');
            item.external_id = s.Id;
            items.add(item);
        }
        return items;
    }

    /**
    * @description Query Orders with all fields needed for MKIS integration.
    **/
    public static List<Order> queryOrders(List<Id> orderIds) {
        return [
            SELECT Id, OrderNumber, Status, ChargeIdentifier__c, Guild__c, AccountTypeRelated__c,
                   Urgent__c, Observaciones__c, Type, ProviderType__c, ProviderReference__c,
                   /* Causa__c, SubCausa__c, */ OPFVTSIndicatorsPresent__c, RelatedOrder__c,
                   ContactedPerson__c, ContactDateTime__c, ContactMade__c,
                   FailedContactReason__c, VisitDateTime__c, VisitType__c,
                   CaseNumber__c,
                   CaseNumber__r.CaseNumber,
                   CaseNumber__r.GrandAccount__c,
                   CaseNumber__r.ClaimDate__c,
                   CaseNumber__r.Coverage__c,
                   CaseNumber__r.Description,
                   CaseNumber__r.ClaimsHandlerName__c,
                   CaseNumber__r.ClaimsHandlerEmail__c,
                   CaseNumber__r.InsurerClaimReference__c,
                   CaseNumber__r.ParticipationDate__c,
                   CaseNumber__r.Reason__c,
                   CaseNumber__r.SubReason__c,
                   Account.RepairAutonomy__c,
                   Account.ReducedVATValue__c,
                   Account.ReducedVAT__c,
                   Account.VAT__c,
                   CaseNumber__r.RelationshiptotheInsured__c,
                   //CaseNumber__r.CorrosionPresent__c,
                   CaseNumber__r.Marcadores__c,
                   CaseNumber__r.IncidentDate__c,
                   AccountId,
                   Account.Name,
                   Account.TaxNumber__c,
                   Account.SAPEntityCode__c,
                   Account.RecordType.DeveloperName,
                   Account.Guild__c,
                   BillToContactId,
                   BillToContact.Name,
                   BillToContact.FirstName,
                   BillToContact.LastName,
                   BillToContact.PolicyNumber__c,
                   BillToContact.IDNumber__c,
                   BillToContact.Phone,
                   BillToContact.MobilePhone,
                   BillToContact.Email,
                   BillToContact.MailingStreet,
                   BillToContact.MailingCity,
                   BillToContact.MailingPostalCode,
                   BillToContact.MailingState,
                   BillToContact.MailingCountry,
                   BillToContact.BuildingCapital__c,
                   BillToContact.FillingCapital__c,
                   BillToContact.LiabilityCapital__c,
                   BillToContact.PolicyStartDate__c,
                /*    BillToContact.LineOfBusiness__c, */
                   BillToContact.IsVIP__c,
                   Reason__c,
                   SubReason__c,
                   Coverage__c,
                   VisitCompleted__c,
                   VisitNotCompletedReason__c,
                   OperatorDescription__c,
                   OperatorAssessment__c,
                   OriginIdentification__c,
                   DamagePriortoPolicyInception__c,
                   DamagePriortoDateofOccurrence__c,
                   OngoingDamage__c,
                   DamageDuetoLackofMaintenance__c,
                   ClaimCoverage__c,
                   Rejection__c,
                   MeetsVATConditions__c,
                   InitialDamagesLocated__c,
                   InitialDamagesRepaired__c,
                   NoRepairReason__c,
                   AdjusterInterventionRequired__c,
                   ReasonforAdjusterIntervention__c,
                   TotalBudgetAmount__c,
                   ReasonForNoAppointmentScheduled__c,
                   CaseNumber__r.DamagesIncurred__c,
                   CaseNumber__r.AntiCorrosion__c,
                   CaseNumber__r.LowExpiration__c,
                   CaseNumber__r.ServiceNearPolicy__c,
                   CaseNumber__r.CTEAestheticCapitalLimit__c,
                   CaseNumber__r.CDOAestheticCapitalLimit__c
            FROM Order
            WHERE Id IN :orderIds
        ];
    }

    /**
    * @description Determines whether the Order is related to a Supplier account.
    * @param ord The Order record
    * @return Boolean true when the related account is a Supplier
    **/
    private static Boolean isSupplierOrder(Order ord) {
        if (ord == null) {
            return false;
        }

        if (String.valueOf(ord.get('AccountTypeRelated__c')) == SUPPLIER_RECORD_TYPE) {
            return true;
        }

        return ord.Account != null
            && ord.Account.RecordType != null
            && ord.Account.RecordType.DeveloperName == SUPPLIER_RECORD_TYPE;
    }

    /**
    * @description Handles attempts to send non-supplier orders to MKIS.
    * @param ord The Order record
    * @param source Integration source identifier
    **/
    private static void handleNonSupplierOrder(Order ord, String source) {
        if (ord == null || ord.Id == null) {
            return;
        }

        logError(ord.Id, NON_SUPPLIER_ACCOUNT_MESSAGE, source);
        sendResponseEvent(ord.Id, false, NON_SUPPLIER_ACCOUNT_MESSAGE);
    }

    /**
    * @description Extracts the set of Account Ids from a list of Orders.
    * @param orders List of Order records
    * @return Set of Account Ids
    **/
    private static Set<Id> getAccountIds(List<Order> orders) {
        Set<Id> accountIds = new Set<Id>();
        for (Order ord : orders) {
            if (ord.AccountId != null) {
                accountIds.add(ord.AccountId);
            }
        }
        return accountIds;
    }

    /**
    * @description Queries AccountInformation__c records grouped by Account Id.
    * @param accountIds Set of Account Ids to query
    * @return Map of Account Id to list of AccountInformation__c records
    **/
    private static Map<Id, List<AccountInformation__c>> queryAccountInformationByAccountIds(Set<Id> accountIds) {
        Map<Id, List<AccountInformation__c>> accountInfoByAccountId = new Map<Id, List<AccountInformation__c>>();
        if (accountIds == null || accountIds.isEmpty()) {
            return accountInfoByAccountId;
        }

        for (AccountInformation__c accountInfo : [
            SELECT Account__c, Type__c, Value__c, Description__c
            FROM AccountInformation__c
            WHERE Account__c IN :accountIds
            ORDER BY CreatedDate DESC
        ]) {
            if (!accountInfoByAccountId.containsKey(accountInfo.Account__c)) {
                accountInfoByAccountId.put(accountInfo.Account__c, new List<AccountInformation__c>());
            }
            accountInfoByAccountId.get(accountInfo.Account__c).add(accountInfo);
        }

        return accountInfoByAccountId;
    }

    /**
    * @description Retrieves the email value from AccountInformation__c records with OCE description.
    * @param accountInfoList List of AccountInformation__c records for the account
    * @return The email value string, or null if not found
    **/
    private static String getEmailAccountInformation(List<AccountInformation__c> accountInfoList) {
        return getAccountInformationValue(accountInfoList, ACCOUNT_INFO_TYPE_EMAIL, new Set<String>{ 'OPE' });
    }

    /**
    * @description Retrieves the operator phone value from AccountInformation__c records, checking OPE, OP, and OCE descriptions in order.
    * @param accountInfoList List of AccountInformation__c records for the account
    * @return The phone value string, or null if not found
    **/
    private static String getOperatorPhoneAccountInformation(List<AccountInformation__c> accountInfoList) {
        String phoneValue = getAccountInformationValue(accountInfoList, ACCOUNT_INFO_TYPE_PHONE, new Set<String>{ 'OPE' });
        if (String.isNotBlank(phoneValue)) {
            return phoneValue;
        }

        phoneValue = getAccountInformationValue(accountInfoList, ACCOUNT_INFO_TYPE_PHONE, new Set<String>{ 'OP' });
        if (String.isNotBlank(phoneValue)) {
            return phoneValue;
        }

        return getAccountInformationValue(accountInfoList, ACCOUNT_INFO_TYPE_PHONE, new Set<String>{ 'OCE' });
    }

    /**
    * @description Finds the first matching AccountInformation__c value by type and description filter.
    * @param accountInfoList List of AccountInformation__c records
    * @param typeValue The Type__c value to match (e.g. 'Email', 'Phone')
    * @param descriptionFilter Set of Description__c values to filter by
    * @return The matching Value__c string, or null if not found
    **/
    private static String getAccountInformationValue(
        List<AccountInformation__c> accountInfoList,
        String typeValue,
        Set<String> descriptionFilter
    ) {
        if (accountInfoList == null || accountInfoList.isEmpty()) {
            return null;
        }

        for (AccountInformation__c accountInfo : accountInfoList) {
            if (accountInfo.Type__c != typeValue) {
                continue;
            }
            if (descriptionFilter != null && !descriptionFilter.isEmpty() && !descriptionFilter.contains(accountInfo.Description__c)) {
                continue;
            }
            if (String.isNotBlank(accountInfo.Value__c)) {
                return accountInfo.Value__c;
            }
        }

        return null;
    }

    /**
    * @description Parses the Create Service API response and saves MKIS ids on Stakeholders__c and InsurableCoverage__c records.
    * @param responseBody The raw HTTP response body from the create service call
    **/
    @TestVisible
    private static void saveMkisIdsFromServiceResponse(String responseBody) {
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            Object dataObj = parsed.get('data');
            if (!(dataObj instanceof Map<String, Object>)) return;
            Map<String, Object> data = (Map<String, Object>) dataObj;

            // Update Stakeholders__c.MKISId__c using external_id as Salesforce record Id
            Object stakeholdersObj = data.get('stakeholders');
            if (stakeholdersObj instanceof List<Object>) {
                List<Stakeholders__c> stakeholdersToUpdate = new List<Stakeholders__c>();
                for (Object item : (List<Object>) stakeholdersObj) {
                    if (!(item instanceof Map<String, Object>)) continue;
                    Map<String, Object> sh = (Map<String, Object>) item;
                    Object mkisId = sh.get('id');
                    Object extId  = sh.get('external_id');
                    if (mkisId == null || extId == null) continue;
                    stakeholdersToUpdate.add(new Stakeholders__c(
                        Id = (String) extId,
                        MKISId__c = String.valueOf(mkisId)
                    ));
                }
                if (!stakeholdersToUpdate.isEmpty()) {
                    update stakeholdersToUpdate;
                }
            }

            // Update InsurableCoverage__c.MKISId__c using external_id as Salesforce record Id
            /* Object coveragesObj = data.get('service_coverages');
            if (coveragesObj instanceof List<Object>) {
                List<InsurableCoverage__c> coveragesToUpdate = new List<InsurableCoverage__c>();
                for (Object item : (List<Object>) coveragesObj) {
                    if (!(item instanceof Map<String, Object>)) continue;
                    Map<String, Object> cov = (Map<String, Object>) item;
                    Object mkisId = cov.get('id');
                    Object extId  = cov.get('external_id');
                    if (mkisId == null || extId == null) continue;
                    coveragesToUpdate.add(new InsurableCoverage__c(
                        Id = (String) extId,
                        MKISId__c = String.valueOf(mkisId)
                    ));
                }
                if (!coveragesToUpdate.isEmpty()) {
                    update coveragesToUpdate;
                }
            } */
        } catch (Exception e) {
            System.debug('saveMkisIdsFromServiceResponse error: ' + e.getMessage());
        }
    }

    /**
    * @description Parses the API JSON response body to extract the message field.
    * @param responseBody The raw HTTP response body
    * @return The extracted message string, or the raw body if parsing fails
    **/
    private static String parseApiMessage(String responseBody) {
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            if (parsed.containsKey('message')) {
                return (String) parsed.get('message');
            }
        } catch (Exception e) {
            // Response is not valid JSON, fall through to return raw body
        }
        return responseBody;
    }

    /**
    * @description Parses the API JSON response body to extract the nested data.url field.
    * @param responseBody The raw HTTP response body
    * @return The extracted url string, or null if not found
    **/
    private static String parseApiUrl(String responseBody) {
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            Object dataObject = parsed.get('data');
            if (dataObject instanceof Map<String, Object>) {
                Object urlValue = ((Map<String, Object>) dataObject).get('url');
                if (urlValue instanceof String) {
                    return (String) urlValue;
                }
            }
        } catch (Exception e) {
            // Response is not valid JSON or does not contain the expected structure
        }

        return null;
    }

    /**
    * @description Publishes a PopUP_Service__e platform event with the integration result.
    * @param orderId The Order record Id
    * @param isSuccess Whether the API call was successful
    * @param message The response message
    **/
    private static void sendResponseEvent(Id orderId, Boolean isSuccess, String message) {
        PopUP_Service__e responseEvent = new PopUP_Service__e(
            RecordId__c = String.valueOf(orderId),
            Message__c = message,
            Success__c = isSuccess
        );
        EventBus.publish(responseEvent);
    }

    /**
    * @description Logs the integration result on the Order record.
    * @param orderId The Order record Id
    * @param res The HTTP response from the API call
    * @param source The source identifier for the integration log
    **/
    private static void logIntegration(Id orderId, HttpResponse res, String source) {
        Order orderToUpdate = new Order(Id = orderId);
        orderToUpdate.LastIntegrationDateTime__c = System.now();
        orderToUpdate.LastIntegration__c = source;
        orderToUpdate.LastIntegrationDescription__c = res.getStatusCode() == 200
            ? 'Success' : 'Error ' + res.getStatusCode() + ': ' + res.getBody();
        if (res.getStatusCode() == 200) {
            System.debug(res.getBody());
            String iFrameUrl = parseApiUrl(res.getBody());
            if (String.isNotBlank(iFrameUrl)) {
                orderToUpdate.iFrame__c = iFrameUrl;
            }
        }
        update orderToUpdate;
    }

    /**
    * @description Logs an error on the Order record when an exception occurs during integration.
    * @param orderId The Order record Id
    * @param errorMessage The error message to log
    * @param source The source identifier for the integration log
    **/
    private static void logError(Id orderId, String errorMessage, String source) {
        Order orderToUpdate = new Order(Id = orderId);
        orderToUpdate.LastIntegrationDateTime__c = System.now();
        orderToUpdate.LastIntegration__c = source;
        orderToUpdate.LastIntegrationDescription__c = 'Exception: ' + errorMessage;
        update orderToUpdate;
    }
}