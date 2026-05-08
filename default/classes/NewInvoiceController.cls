/**
 * @description Apex controller for the newInvoice LWC component.
 *              Handles data retrieval and Invoice__c creation from Order Services.
 * @author      Daniel Flores
 * @group       Invoice
 * @last modified on  : 30-04-2026
 */
public with sharing class NewInvoiceController {

    /**
     * @description Returns Order header data for the modal (order number, account,
     *              case, and picklist labels for Guild, ProviderType and Type).
     */
    @AuraEnabled
    public static Map<String, String> getOrderData(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('orderId is required.');
        }
        List<Order> orders = [
            SELECT Id, OrderNumber, Account.Name, CaseNumber__c,
                   Guild__c, ProviderType__c, Type
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];
        if (orders.isEmpty()) {
            throw new AuraHandledException('Order not found: ' + orderId);
        }
        Order ord = orders[0];

        return new Map<String, String>{
            'orderName'    => ord.OrderNumber,
            'accountName'  => ord.Account.Name,
            'caseId'       => ord.CaseNumber__c != null ? String.valueOf(ord.CaseNumber__c) : null,
            'guild'        => getMultiPicklistLabels(Order.Guild__c, ord.Guild__c),
            'providerType' => getPicklistLabel(Order.ProviderType__c, ord.ProviderType__c),
            'orderType'    => getPicklistLabel(Order.Type, ord.Type)
        };
    }

    /**
     * @description Returns services for the given Order that have not yet been
     *              covered by an existing Invoice (matched by guild / Type__c).
     *              Picklist Type__c is returned as its display label.
     */
    @AuraEnabled
    public static List<ServiceWrapper> getServicesForOrder(Id orderId) {

        // Collect guild API values already covered by an Invoice on this Order
        Set<String> invoicedGuilds = new Set<String>();
        for (Invoice__c inv : [
            SELECT Guilds__c
            FROM Invoice__c
            WHERE Order__c             = :orderId
              AND RecordType.DeveloperName = 'Invoice'
              AND Guilds__c            != null
        ]) {
            for (String g : inv.Guilds__c.split(';')) {
                String trimmed = g.trim();
                if (String.isNotBlank(trimmed)) {
                    invoicedGuilds.add(trimmed);
                }
            }
        }

        List<ServiceWrapper> result = new List<ServiceWrapper>();
        for (Service__c svc : [
            SELECT Id, Name, Type__c,
                   Stakeholder__r.Name,
                   TotalAmount__c, VATAmount__c, TotalAmountWithVAT__c
            FROM Service__c
            WHERE Order__c = :orderId
            ORDER BY Name
        ]) {
            // Exclude services whose guild is already invoiced
            if (String.isNotBlank(svc.Type__c) && invoicedGuilds.contains(svc.Type__c)) {
                continue;
            }
            result.add(new ServiceWrapper(svc));
        }
        return result;
    }

    /**
     * @description Creates one Invoice__c (Invoice record type) for the Order,
     *              populated with the guilds from the selected services.
     */
    @AuraEnabled
    public static Id createInvoice(Id orderId, List<Id> serviceIds, Id caseId) {

        // ── Collect guilds + amounts from selected services ───────────────
        List<Service__c> services = [
            SELECT Type__c, TotalAmount__c, VATAmount__c, TotalAmountWithVAT__c
            FROM Service__c
            WHERE Id IN :serviceIds
        ];

        Set<String> guildsSet        = new Set<String>();
        Decimal totalWithoutVAT      = 0;
        Decimal totalVATAmount       = 0;
        Decimal totalWithVAT         = 0;

        for (Service__c svc : services) {
            if (String.isNotBlank(svc.Type__c)) {
                guildsSet.add(svc.Type__c);
            }
            totalWithoutVAT += svc.TotalAmount__c        != null ? svc.TotalAmount__c        : 0;
            totalVATAmount  += svc.VATAmount__c          != null ? svc.VATAmount__c          : 0;
            totalWithVAT    += svc.TotalAmountWithVAT__c != null ? svc.TotalAmountWithVAT__c : 0;
        }
        String guildsValue = String.join(new List<String>(guildsSet), ';');

        // ── Determine billing account ─────────────────────────────────────/* Account.Iva__c, *//* Account.Parent.Iva__c */
        List<Order> ordList = [
            SELECT AccountId, Account.Pere__c, Account.ParentId,
                   Account.SAPEntityCode__c, 
                   Account.Parent.SAPEntityCode__c
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];
        if (ordList.isEmpty()) {
            throw new AuraHandledException('Order not found: ' + orderId);
        }
        Order ord = ordList[0];

        Id     billingAccountId = ord.AccountId;
        String sapEntityCode    = ord.Account.SAPEntityCode__c;
        /* Decimal ivaNumber       = ord.Account.Iva__c; */

        if (String.isNotBlank(ord.Account.Pere__c) && ord.Account.ParentId != null) {
            billingAccountId = ord.Account.ParentId;
            sapEntityCode    = ord.Account.Parent.SAPEntityCode__c;
            /* ivaNumber        = ord.Account.Parent.Iva__c; */
        }

        // Map IVA numeric value → VATPercentage__c picklist API value
        // Picklist values: 0, 4, 10, 21 — IVA formula returns 4, 7 or 21
        String vatPercentage;
       /*  if (ivaNumber != null) {
            Integer ivaInt = ivaNumber.intValue();
            if (ivaInt == 4)       vatPercentage = '4';
            else if (ivaInt == 7)  vatPercentage = '10'; // IGIC (Canarias) – nearest valid value
            else if (ivaInt == 21) vatPercentage = '21';
            else                   vatPercentage = String.valueOf(ivaInt);
        } */

        if (String.isBlank(sapEntityCode)) {
            sapEntityCode = 'UNKNOWN';
        }

        // ── Sequential Invoice number ─────────────────────────────────────
        Integer existingCount = [
            SELECT COUNT()
            FROM Invoice__c
            WHERE RecordType.DeveloperName = 'Invoice'
              AND Order__r.AccountId        = :billingAccountId
        ];

        String invoiceNumber = 'PF/' + sapEntityCode + '/' +
                               String.valueOf(existingCount + 1).leftPad(5, '0');

        // ── RecordType ────────────────────────────────────────────────────
        Id invoiceRtId = Schema.SObjectType.Invoice__c
            .getRecordTypeInfosByDeveloperName()
            .get('Invoice')
            .getRecordTypeId();

        // ── Insert ────────────────────────────────────────────────────────
        Invoice__c inv = new Invoice__c(
            RecordTypeId              = invoiceRtId,
            Order__c                  = orderId,
            Case__c                   = caseId,
            Guilds__c                 = guildsValue,
            Provider__c               = billingAccountId,
            PreInvoiceNumber__c       = invoiceNumber,
            PreInvoiceDate__c         = Datetime.now(),
            VATPercentage__c          = vatPercentage,
            TotalAmountWithoutVAT__c  = totalWithoutVAT,
            VATAmount__c              = totalVATAmount,
            TotalAmountWithVAT__c     = totalWithVAT,
            Status__c                 = 'Open'
        );

        insert inv;

        // ── Link Products__c to the created Invoice ───────────────────────
        List<Products__c> products = [
            SELECT Id
            FROM Products__c
            WHERE IDService__c IN :serviceIds
        ];
        if (!products.isEmpty()) {
            for (Products__c p : products) {
                p.Invoice__c = inv.Id;
            }
            update products;
        }

        return inv.Id;
    }

    // ─── Picklist helpers ─────────────────────────────────────────────────────

    private static String getPicklistLabel(Schema.SObjectField fieldToken, String apiValue) {
        if (String.isBlank(apiValue)) {
            return apiValue;
        }
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.getValue() == apiValue) {
                return entry.getLabel();
            }
        }
        return apiValue;
    }

    private static String getMultiPicklistLabels(Schema.SObjectField fieldToken, String apiValues) {
        if (String.isBlank(apiValues)) {
            return apiValues;
        }
        Map<String, String> labelsByValue = new Map<String, String>();
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            labelsByValue.put(entry.getValue(), entry.getLabel());
        }
        List<String> labels = new List<String>();
        for (String v : apiValues.split(';')) {
            String t = v.trim();
            if (String.isNotBlank(t)) {
                labels.add(labelsByValue.containsKey(t) ? labelsByValue.get(t) : t);
            }
        }
        return String.join(labels, '; ');
    }

    // ─── Inner Wrapper ────────────────────────────────────────────────────────

    public class ServiceWrapper {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  typeName;         // picklist display label
        @AuraEnabled public String  typeValue;        // API value stored in Guilds__c
        @AuraEnabled public String  stakeholderName;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Decimal vatAmount;
        @AuraEnabled public Decimal totalAmountWithVAT;

        public ServiceWrapper(Service__c svc) {
            this.id                 = svc.Id;
            this.name               = svc.Name;
            this.typeValue          = svc.Type__c;
            this.typeName           = getPicklistLabel(Service__c.Type__c, svc.Type__c);
            this.stakeholderName    = svc.Stakeholder__r != null ? svc.Stakeholder__r.Name : null;
            this.totalAmount        = svc.TotalAmount__c;
            this.vatAmount          = svc.VATAmount__c;
            this.totalAmountWithVAT = svc.TotalAmountWithVAT__c;
        }
    }
}