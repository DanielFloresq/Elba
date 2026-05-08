/**
 * @description       : Data structures for all MKIS ELBA API endpoints.
 * @author            : Daniel Flores
 * @group             : MKIS Integration
 * @last modified on  : 06-05-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class MKISElbaStructures {

    // ===================== CREATE SERVICE (POST /api/services) =====================
    public class CreateServiceRequest {
        public Provider provider;
        public String order_id;                      // Mandatory
        public String order_number;                  // Mandatory
        public String case_id;                       // Mandatory
        public String case_number;                   // Mandatory
        public String policy_number;                 // Mandatory
        public String insurance_company;             // Mandatory
        public String associated_service_order_id;   // Optional
        public Integer urgent;                       // Mandatory
        public String insured_name;                  // Mandatory
        public String insured_identification;        // Mandatory
        public String policy_phone_number;           // Mandatory
        public String address;                       // Mandatory
        public String postal_code;                   // Mandatory
        public String city;                          // Mandatory
        public String district;                      // Mandatory
        public String contact_person;                // Mandatory
        public String contact_relation;              // Optional
        public String contact_phone_number;          // Optional
        public String contact_email_address;         // Optional
        public String contact_telephone_number;      // Mandatory
        public String contact_observations;          // Optional
        public String occurrence_date;               // Optional
        public String observations;                  // Optional
        public String cause;                         // Optional
        public String subcause;                      // Optional
        public String description;                   // Optional
        public String coverage;                      // Optional
        public String warranty;                      // Optional
        public String damage;                        // Optional
        public Decimal cte_capital_limit;            // Optional
        public Decimal cdo_capital_limit;            // Optional
        public Decimal rc_capital_limit;             // Optional
        public Decimal cte_aesthetic_capital_limit;  // Optional
        public Decimal cdo_aesthetic_capital_limit;  // Optional
        public String assigned_job;                  // Optional
        public String operator_name;                 // Optional
        public String operator_email_address;        // Optional
        public String product_code;                  // Optional
        public String sinister_date;                 // Mandatory
        public String declaration_date;              // Optional
        public String policy_effective_date;         // Optional
        public Integer service_near_policy;          // Optional
        public Integer high_frequency;               // Optional
        public Integer anti_corrosion;               // Optional
        public Integer vts_opf_protection;           // Optional
        public Integer low_expiration;               // Optional
        public Integer vip_client;                   // Optional
        public Integer visit;                        // Optional
        public String failed_visit_reason;           // Optional
        public String visit_at;                      // Optional
        public String visit_type;                    // Optional
        public String worker_description;            // Optional
        public String origin_located;              // Optional (String - Identificador Origen)
        public Integer damage_before_policy_inception; // Optional
        public Integer damage_before_occurrence_date;  // Optional
        public Integer opf_vts_indicators;           // Optional
        public Integer continuous_damage_over_time;  // Optional
        public Integer damage_due_to_lack_of_maintenance; // Optional
        public Integer has_coverage;                 // Optional
        public Integer refused;                      // Optional
        public String worker_appreciation;           // Optional
        public Integer meets_tax_condition;          // Optional
        public Integer damage_origin_located;        // Optional
        public Integer damage_origin_repaired;       // Optional
        public String non_repair_reason;             // Optional
        public Integer requires_expert_intervention; // Optional
        public String expert_intervention_reason;    // Optional
        public Decimal gross_total;                  // Optional
        public Decimal vat_total;                    // Optional
        public Decimal total;                        // Optional
        public String budget_state;                  // Optional
        public List<ServiceCoverageItem> service_coverages; // Mandatory
        public List<StakeholderItem> stakeholders;   // Optional
    }

    public class Provider {
        public String name;              // Mandatory
        public String tax_number;        // Mandatory
        public String email;             // Mandatory
        public String phone_number;      // Optional
        public Decimal autonomy;         // Mandatory
        public Integer reduced_vat;      // Mandatory (1|0)
        public Decimal vat_value;        // Mandatory
        public Decimal reduced_vat_value; // Mandatory
        public List<String> categories;  // Optional
    }

    public class ServiceCoverageItem {
        public String code;
        public String coverage;
        public String warranty;
        public Decimal limit_amount;
        public Decimal deductible_amount;
        public String external_id;
    }

    public class StakeholderItem {
        public String name;
        public String stakeholder_type;
        public String tax_number;
        public String phone_number;
        public String address;
        public String external_id;
    }

    // ===================== CREATE STAKEHOLDER (POST /api/stakeholders) =====================
    public class CreateStakeholderRequest {
        public String order_id;          // Mandatory - Salesforce Order Id
        public String name;              // Mandatory
        public String stakeholder_type;  // Mandatory
        public String tax_number;        // Optional
        public String phone_number;      // Optional
        public String address;           // Optional
        public String observations;      // Optional
        public String external_id;       // Mandatory - Salesforce Stakeholder Id
    }

    // ===================== UPDATE STAKEHOLDER (PUT /api/stakeholders/{id}) =====================
    public class UpdateStakeholderRequest {
        public String name;              // Mandatory
        public String stakeholder_type;  // Mandatory
        public String tax_number;        // Optional
        public String phone_number;      // Optional
        public String address;           // Optional
        public String observations;      // Optional
        public String external_id;       // Mandatory - Salesforce Stakeholder Id
    }

    // ===================== UPDATE SERVICE (PUT /api/services) =====================
    public class UpdateServiceRequest {
        public String order_id;
        public String order_number;
        public String case_id;
        public String case_number;
        public String policy_number;
        public String insurance_company;
        public Integer urgent;
        public String insured_name;
        public String insured_identification;
        public String policy_phone_number;
        public String address;
        public String postal_code;
        public String city;
        public String district;
        public String contact_person;
        public String contact_relation;
        public String contact_phone_number;
        public String contact_observations;
        public String occurrence_date;
        public String observations;
        public String cause;
        public String subcause;
        public String description;
        public String coverage;
        public String warranty;
        public String damage;
        public Decimal cte_capital_limit;
        public Decimal cdo_capital_limit;
        public Decimal rc_capital_limit;
        public Decimal cte_aesthetic_capital_limit;
        public Decimal cdo_aesthetic_capital_limit;
        public String assigned_job;
        public String operator_name;
        public String operator_email_address;
        public String product_code;
        public String sinister_date;
        public String declaration_date;
        public String policy_effective_date;
        public Integer service_near_policy;
        public Integer high_frequency;
        public Integer anti_corrosion;
        public Integer vts_opf_protection;
        public Integer low_expiration;
        public Integer vip_client;
        public Integer visit;
        public String failed_visit_reason;
        public String visit_at;
        public String visit_type;
        public String worker_description;
        public String origin_located;
        public Integer damage_before_policy_inception;
        public Integer damage_before_occurrence_date;
        public Integer opf_vts_indicators;
        public Integer continuous_damage_over_time;
        public Integer damage_due_to_lack_of_maintenance;
        public Integer has_coverage;
        public Integer refused;
        public String worker_appreciation;
        public Integer meets_tax_condition;
        public Integer damage_origin_located;
        public Integer damage_origin_repaired;
        public String non_repair_reason;
        public Integer requires_expert_intervention;
        public String expert_intervention_reason;
        public Decimal gross_total;
        public Decimal vat_total;
        public Decimal total;
        public String budget_state;
    }

    // ===================== CREATE CONTACT (POST /api/contacts) =====================
    public class CreateContactRequest {
        public String order_id;                  // Mandatory
        public String contact_at;                // Mandatory - Date of the contact
        public String failed_contact_reason;     // Optional (Mandatory if contact failed)
        public String stakeholder_name;          // Optional (Mandatory if contact succeeded)
        public String failed_scheduling_reason;  // Optional (Mandatory if scheduling failed)
        public String schedule_at;               // Optional (Mandatory if scheduling succeeded)
        public String external_id;
    }

    // ===================== CREATE INCIDENCE (POST /api/incidences) =====================
    public class CreateIncidenceRequest {
        public String order_id;
        public String incidence_type;
        public String incidence_motive;
        public String incidence_submotive;
        public String internal_process;
        public String incidence_management_team;
        public String responsible;
        public String description;
        public String origin;
        public String incidence_result;
        public String incidence_causer_type;
        public String causer;
        public String repairer;
        public String incidence_channel;
        public String state;
        public Integer customer_disagreement;
        public String opened_at;
        public String opened_by;
        public String reopened_at;
        public String reopened_motive;
        public String external_id;
    }

    // ===================== UPDATE INCIDENCE (PUT /api/incidences/{id}) =====================
    public class UpdateIncidenceRequest {
        public String incidence_type;
        public String incidence_motive;
        public String incidence_submotive;
        public String internal_process;
        public String incidence_management_team;
        public String responsible;
        public String description;
        public String origin;
        public String incidence_result;
        public String incidence_causer_type;
        public String causer;
        public String repairer;
        public String incidence_channel;
        public String state;
        public Integer customer_disagreement;
        public String reopened_at;
        public String reopened_motive;
    }

    // ===================== CREATE MESSAGE (POST /api/messages) =====================
    public class CreateMessageRequest {
        public String order_id;
        public String body;
        public List<AttachmentItem> attachments;
    }

    // ===================== CREATE ATTACHMENTS (POST /api/attachments) =====================
    public class CreateAttachmentRequest {
        public String order_id;
        public List<AttachmentItem> attachments;
    }

    public class AttachmentItem {
        public String name;
        public String content;
    }

    // ===================== CREATE INTERVENTION (POST /api/interventions) =====================
    public class CreateInterventionRequest {
        public String order_id;
        public String stakeholder_external_id;
        public String category;
        public String start_date;
        public Integer urgent;
        public String external_id;
        public String situation_type;
        public String state;
    }

    // ===================== UPDATE INTERVENTION (PUT /api/interventions/{id}) =====================
    public class UpdateInterventionRequest {
        public String stakeholder_id;
        public String category;
        public String start_date;
        public Integer urgent;
        public String situation_type;
        public String state;
    }

    // ===================== CREATE SERVICE COVERAGE (POST /api/service-coverages) =====================
    public class CreateServiceCoverageRequest {
        public String case_id;
        public String coverage;
        public Decimal limit_amount;
        public Decimal deductible_amount;
        public String external_id;
    }

    // ===================== GENERIC RESPONSE =====================
    public class ApiResponse {
        public String message;
    }

    public class ApiErrorResponse {
        public String message;
        public Map<String, List<String>> errors;
    }
}