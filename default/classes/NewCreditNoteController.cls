/**
 * @description Apex controller for the newCreditNote LWC component.
 *              Handles data retrieval and creation for Invoice__c Credit Notes.
 * @author      Daniel Flores
 * @group       Invoice
 * @last modified on  : 30-04-2026
 */
public with sharing class NewCreditNoteController {

    /**
     * @description Returns Order data needed to pre-fill the modal.
     */
    @AuraEnabled
    public static Map<String, String> getOrderData(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('orderId is required.');
        }
        List<Order> orders = [
            SELECT Id, OrderNumber, AccountId, Account.Name, CaseNumber__c
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];
        if (orders.isEmpty()) {
            throw new AuraHandledException('Order not found: ' + orderId);
        }
        Order ord = orders[0];
        return new Map<String, String>{
            'orderName'   => ord.OrderNumber,
            'accountId'   => ord.AccountId,
            'accountName' => ord.Account.Name,
            'caseId'      => ord.CaseNumber__c != null ? String.valueOf(ord.CaseNumber__c) : null
        };
    }

    /**
     * @description Returns Invoice__c records (Invoice record type) related to
     *              the given Order that have not yet been linked to a Credit Note.
     */
    @AuraEnabled
    public static List<InvoiceWrapper> getAvailableInvoices(Id orderId) {
        // Collect invoice IDs already referenced by a credit note
        Set<Id> alreadyCredited = new Set<Id>();
        for (Invoice__c cn : [
            SELECT RelatedInvoice__c
            FROM Invoice__c
            WHERE RelatedInvoice__c != null
        ]) {
            alreadyCredited.add(cn.RelatedInvoice__c);
        }

        List<InvoiceWrapper> result = new List<InvoiceWrapper>();
        for (Invoice__c inv : [
            SELECT Id, Name, InvoiceDate__c, TotalAmountWithVAT__c, Order__r.OrderNumber
            FROM Invoice__c
            WHERE Order__c = :orderId
              AND RecordType.DeveloperName = 'Invoice'
              AND Id NOT IN :alreadyCredited
            ORDER BY InvoiceDate__c DESC
        ]) {
            result.add(new InvoiceWrapper(inv));
        }
        return result;
    }

    /**
     * @description Returns picklist options for RectificationReason__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getRectificationReasonOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Schema.DescribeFieldResult fieldResult =
            Invoice__c.RectificationReason__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }
        return options;
    }

    /**
     * @description Creates an Invoice__c Credit Note record linked to the
     *              selected invoices. One credit note is created per selected invoice.
     *              CreditNoteNumber__c format: FT/{SAPEntityCode}/{counter 5-digit}
     *              Billing account: if Order Account has Pere__c filled → use ParentId account,
     *              otherwise use the Order Account itself.
     */
    @AuraEnabled
    public static List<Id> createCreditNotes(
        Id orderId,
        String rectificationReason,
        List<Id> relatedInvoiceIds,
        Id caseId
    ) {
        Id creditNoteRecordTypeId = Schema.SObjectType.Invoice__c
            .getRecordTypeInfosByDeveloperName()
            .get('CreditNote')
            .getRecordTypeId();

        // ── Determine billing account ─────────────────────────────────────
        List<Order> ordList = [
            SELECT AccountId, Account.Pere__c, Account.ParentId, 
                   Account.SAPEntityCode__c,/* Account.Iva__c, */
                   Account.Parent.SAPEntityCode__c /* ,Account.Parent.Iva__c */
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];
        if (ordList.isEmpty()) {
            throw new AuraHandledException('Order not found: ' + orderId);
        }
        Order ord = ordList[0];

        Id    billingAccountId  = ord.AccountId;
        String sapEntityCode    = ord.Account.SAPEntityCode__c;
       /*  Decimal ivaNumber       = ord.Account.Iva__c; */

        if (String.isNotBlank(ord.Account.Pere__c) && ord.Account.ParentId != null) {
            billingAccountId  = ord.Account.ParentId;
            sapEntityCode     = ord.Account.Parent.SAPEntityCode__c;
          /*   ivaNumber        = ord.Account.Parent.Iva__c; */
        }

        // Map IVA numeric value → VATPercentage__c picklist API value
        // Picklist values: 0, 4, 10, 21 — IVA formula returns 4, 7 or 21
        String vatPercentage;
        /* if (ivaNumber != null) {
            Integer ivaInt = ivaNumber.intValue();
            if (ivaInt == 4)       vatPercentage = '4';
            else if (ivaInt == 7)  vatPercentage = '10'; // IGIC (Canarias) – nearest valid value
            else if (ivaInt == 21) vatPercentage = '21';
            else                   vatPercentage = String.valueOf(ivaInt);
        } */
        if (String.isBlank(sapEntityCode)) {
            sapEntityCode = 'UNKNOWN';
        }

        // ── Count existing credit notes for this billing account ──────────
        Integer existingCount = [
            SELECT COUNT()
            FROM Invoice__c
            WHERE RecordType.DeveloperName = 'CreditNote'
              AND Order__r.AccountId        = :billingAccountId
        ];

        // ── Build records ─────────────────────────────────────────────────
        List<Invoice__c> creditNotes = new List<Invoice__c>();
        Integer counter = existingCount;
        for (Id invoiceId : relatedInvoiceIds) {
            counter++;
            String creditNoteNumber = 'AB/' + sapEntityCode + '/' + String.valueOf(counter).leftPad(5, '0');
            creditNotes.add(new Invoice__c(
                RecordTypeId           = creditNoteRecordTypeId,
                Order__c               = orderId,
                RectificationReason__c = rectificationReason,
                RelatedInvoice__c      = invoiceId,
                Case__c                = caseId,
                VATPercentage__c          = vatPercentage,
                CreditNoteNumber__c    = creditNoteNumber,
                Provider__c            = billingAccountId,
                CreditNoteDate__c       = Date.today(),
                Status__c             = 'Open'
            ));
        }

        insert creditNotes;

        List<Id> createdIds = new List<Id>();
        for (Invoice__c cn : creditNotes) {
            createdIds.add(cn.Id);
        }
        return createdIds;
    }

    // ─── Inner Wrapper ────────────────────────────────────────────────────────

    public class InvoiceWrapper {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
        @AuraEnabled public String invoiceDate;
        @AuraEnabled public Decimal totalAmountWithVAT;
        @AuraEnabled public String orderNumber;
        @AuraEnabled public Boolean selected;

        public InvoiceWrapper(Invoice__c inv) {
            this.id                 = inv.Id;
            this.name               = inv.Name;
            this.invoiceDate        = inv.InvoiceDate__c != null
                                        ? inv.InvoiceDate__c.format()
                                        : null;
            this.totalAmountWithVAT = inv.TotalAmountWithVAT__c;
            this.orderNumber        = inv.Order__r?.OrderNumber;
            this.selected           = false;
        }
    }
}