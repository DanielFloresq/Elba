/**
 * @description       : Invocable action for sending Pelayo encargo (assignment) update requests
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 23-02-2026
 * @last modified by  : Afonso Duque
**/
public with sharing class PutPelayoEncargoAction {

    /**
     * @description Sends Pelayo encargo update requests for each provided request record
     * @param requests List of PutPelayoEncargoRequest containing encargo IDs and type
     */
    @InvocableMethod(label='Put Pelayo Encargo' description='Invocable method to put encargo to Pelayo' category='Pelayo')
    public static void putEncargo(List<PutPelayoEncargoRequest> requests) {
        for (PutPelayoEncargoRequest request : requests) {
            PelayoWebServiceController.sendEncargoPelayoService(request.encargoIds, request.type, System.isFuture());
        }
    }

    public class PutPelayoEncargoRequest {
        @InvocableVariable(label='Type' description='Type of Service Call')
        public String type;

        @InvocableVariable(label='Order Ids' description='Order Ids' required=true)
        public List<String> encargoIds;
    }

}