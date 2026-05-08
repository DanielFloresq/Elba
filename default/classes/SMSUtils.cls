/**
 * @description       : Utility class for SMS messaging with authorization and delivery support
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 29-01-2026
 * @last modified by  : Afonso Duque
**/
public with sharing class SMSUtils {

    /**
    * @description Gets the authorization token.
    * @author Afonso Duque | 09-10-2025
    * @return String
    **/
    public static AuthCredentials getAuthorizationCredentials() {

        AuthCredentials authCredentials = new AuthCredentials('', '');

        HttpResponse response = NamedCredentialsCalloutClass.doGet('SMSToken', '');
        System.debug(LoggingLevel.DEBUG, 'Status Code: ' + response.getStatusCode());
        System.debug(LoggingLevel.DEBUG, 'Response: ' + response.getBody());

        if (response.getStatusCode() == 200) {
            if(!String.isBlank(response.getBody())){
                List<String> authResponse = response.getBody().split(';');
                authCredentials.user_key = authResponse[0].trim();
                authCredentials.access_token = authResponse[1].trim();
                System.debug(LoggingLevel.DEBUG, 'SMS Token: ' + authCredentials);
            } else {
                System.debug(LoggingLevel.ERROR, 'Error obtaining SMS auth token: Empty response body');
            }
        } else {
            System.debug(LoggingLevel.ERROR, 'Error obtaining SMS auth token: ' + response.getStatusCode() + ' - ' + (String.isBlank(response.getBody()) ? 'Sin contenido' : response.getBody()));
        }

        return authCredentials;
    }

    /**
    * @description Sends an SMS message using the provided phone number, text message, and sender ID.
    * @author Afonso Duque | 29-01-2026
    * @param String phoneNumber
    * @param String textMessage
    * @param String sender
    * @return ServiceResponse
    **/
    public static ServiceResponse sendSMSMessage(String phoneNumber, String textMessage, String sender) {
        AuthCredentials authCredentials = getAuthorizationCredentials();
        return sendSMSMessage(authCredentials, phoneNumber, textMessage, sender);
    }

    /**
    * @description Sends an SMS message using the provided authorization credentials, phone number, text message, and sender ID.
    * @author Afonso Duque | 29-01-2026
    * @param AuthCredentials authCredentials
    * @param String phoneNumber
    * @param String textMessage
    * @param String sender
    * @return ServiceResponse
    **/
    public static ServiceResponse sendSMSMessage(AuthCredentials authCredentials, String phoneNumber, String textMessage, String sender) {

        ServiceResponse serviceResponse = new ServiceResponse();
        try {

            Map<String, String> mapHeaders = new Map<String, String>();
            mapHeaders.put('Content-Type', 'application/json');
            mapHeaders.put('access_token', authCredentials.access_token);
            mapHeaders.put('user_key', authCredentials.user_key);

            String serviceBody = JSON.serializePretty(new SMSBody(phoneNumber, textMessage, sender));

            HttpResponse response = NamedCredentialsCalloutClass.doPostWithCustomHeaders('SendSMS', '', serviceBody, mapHeaders);
            System.debug(LoggingLevel.DEBUG, 'Status Code: ' + response.getStatusCode());
            System.debug(LoggingLevel.DEBUG, 'Response: ' + response.getBody());

            if(response.getStatusCode() == 201){
                serviceResponse.smsResponse = (SMSResponse) JSON.deserialize(response.getBody(), SMSResponse.class);
                System.debug(LoggingLevel.DEBUG, 'SMS Response: ' + JSON.serializePretty(serviceResponse.smsResponse));
            } else {
                serviceResponse = new ServiceResponse(false, 'Error sending SMS: ' + response.getStatusCode() + ' - ' + (String.isBlank(response.getBody()) ? 'Sin contenido' : response.getBody()));
                System.debug(LoggingLevel.ERROR, serviceResponse.message);
            }

        } catch (Exception e) {
            serviceResponse = new ServiceResponse(false, 'Exception: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, serviceResponse.message);
        }

        return serviceResponse;
    }

    public class AuthCredentials {
        public String access_token;
        public String user_key;

        public AuthCredentials(String access_token, String user_key) {
            this.access_token = access_token;
            this.user_key = user_key;
        }
    }

    public class SMSBody {
        public Boolean returnCredits;
        public Boolean returnRemaining;
        public List<String> recipient;
        public String message;
        public String message_type;
        public String sender;

        public SMSBody(String phoneNumber, String textMessage, String alphaOriginator) {
            this.returnCredits = true;
            this.returnRemaining = true;
            this.recipient = new List<String>{phoneNumber};
            this.message = textMessage;
            this.message_type = 'GP';
            this.sender = alphaOriginator;
        }
    }

    public class SMSResponse {
        public String result;
        public String order_id;
        public String total_sent;
        public String used_credits;
        public String remaining_credits;
        public String internal_order_id;
    }

    public class ServiceResponse {
        @AuraEnabled
        public Boolean isSuccess;
        @AuraEnabled
        public String message;
        @AuraEnabled
        public SMSResponse smsResponse;

        public ServiceResponse() {
            this.isSuccess = true;
            this.message = '';
        }

        public ServiceResponse(Boolean isSuccess, String message) {
            this.isSuccess = isSuccess;
            this.message = message;
        }
    }
}