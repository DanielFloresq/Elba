/**
 * @description       : Handles Create Contact calls to MKIS ELBA API.
 *                      Triggered when certain fields on Order are updated.
 * @author            : Daniel Flores
 * @group             : MKIS Integration
 * @last modified on  : 05-05-2026
 * @last modified by  : Daniel Flores
**/
public without sharing class MKISElbaContactHandler {

    private static final String ENDPOINT_CONTACTS = '/contacts';

    public static final Set<String> CONTACT_TRIGGER_FIELDS = new Set<String>{
        'ContactedPerson__c',
        'ContactDateTime__c',
        'FailedContactReason__c',
        'VisitDateTime__c',
        'ReasonForNoAppointmentScheduled__c'
    };

    /**
    * @description Checks if any of the contact-related fields changed on the Order.
    * @param newOrder The new Order record
    * @param oldOrder The old Order record
    * @return Boolean true if contact fields changed
    **/
    public static Boolean hasContactFieldsChanged(Order newOrder, Order oldOrder) {
        if (oldOrder == null) return false;
        for (String fieldName : CONTACT_TRIGGER_FIELDS) {
            try {
                Object newVal = newOrder.get(fieldName);
                Object oldVal = oldOrder.get(fieldName);
                if (newVal != oldVal) {
                    return true;
                }
            } catch (Exception e) {
                continue;
            }
        }
        return false;
    }

    /**
    * @description Creates a contact in MKIS ELBA when relevant Order fields change.
    * @param orderIds List of Order Ids to process
    **/
    @future(callout=true)
    public static void createContactAsync(List<Id> orderIds) {
        List<Order> orders = MKISElbaServiceHandler.queryOrders(orderIds);
        for (Order ord : orders) {
            createContact(ord);
        }
    }

    /**
    * @description Creates a contact in MKIS ELBA for a single Order.
    * @param ord The Order record
    **/
    public static void createContact(Order ord) {
        MKISElbaStructures.CreateContactRequest req = buildCreateContactRequest(ord);
        String body = JSON.serialize(req, true);
        System.debug(body);

        try {
            HttpResponse res = MKISElbaCalloutService.doPost(ENDPOINT_CONTACTS, body);
            System.debug('MKIS Create Contact response: ' + res.getStatusCode() + ' - ' + res.getBody());
            sendResponseEvent(ord.Id, res.getStatusCode() == 200, parseApiMessage(res.getBody()));
        } catch (Exception e) {
            System.debug('MKIS Create Contact error: ' + e.getMessage());
            sendResponseEvent(ord.Id, false, e.getMessage());
        }
    }

    /**
    * @description Builds the Create Contact request.
    **/
    private static MKISElbaStructures.CreateContactRequest buildCreateContactRequest(Order ord) {
        MKISElbaStructures.CreateContactRequest req = new MKISElbaStructures.CreateContactRequest();

        // order_id: Mandatory
        req.order_id = String.valueOf(ord.Id);

        // contact_at: Mandatory - ContactDateTime__c
        req.contact_at = ord.ContactDateTime__c != null
            ? formatDateTimeForApi(ord.ContactDateTime__c)
            : formatDateTimeForApi(Datetime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0)));

        // failed_contact_reason: Mandatory if contact failed (ThereWasContact__c = FailedContactReason == null)
        req.failed_contact_reason = ord.FailedContactReason__c != null
            ? ord.FailedContactReason__c
            : null;

        // stakeholder_name: Mandatory if contact succeeded - ContactedPerson__c
        req.stakeholder_name = String.isNotBlank(ord.ContactedPerson__c)
            ? ord.ContactedPerson__c
            : ord.BillToContact != null ? ord.BillToContact.Name : null;

        // failed_scheduling_reason: Mandatory if scheduling failed - ReasonForNoAppointmentScheduled__c
        req.failed_scheduling_reason = ord.ReasonForNoAppointmentScheduled__c != null
            ? ord.ReasonForNoAppointmentScheduled__c
            : null;

        // schedule_at: Mandatory if scheduling succeeded - VisitDateTime__c (AppointmentDateTime)
        req.schedule_at = ord.VisitDateTime__c != null
            ? formatDateTimeForApi(ord.VisitDateTime__c)
            : null;

        req.external_id = String.valueOf(ord.Id);

        System.debug(JSON.deserialize(JSON.serialize(req), MKISElbaStructures.CreateContactRequest.class));
        return req;
    }

    private static String formatDateTimeForApi(Datetime value) {
        return value == null ? null : JSON.serialize(value).replace('"', '');
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
        }
        return responseBody;
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
}