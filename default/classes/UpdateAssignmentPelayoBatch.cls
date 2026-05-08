/**
 * @description       : Batch class for updating Pelayo assignment statuses in bulk
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 26-02-2026
 * @last modified by  : Afonso Duque
**/
public class UpdateAssignmentPelayoBatch implements Database.Batchable<String>, Database.Stateful, Database.AllowsCallouts {

    private List<String> listOrderIds;
    private String type;

    /*private List<Order> listOrder;
    private String type;
    private String token;
    private Map<String, String> mapAccountInformation;
    private WebServiceUtils__mdt config;*/

    /*public UpdateAssignmentPelayoBatch(WebServiceUtils__mdt config, List<Order> listOrder, String type, String token, Map<String, String> mapAccountInformation) {
        this.config = config;
        this.listOrder = listOrder;
        this.type = type;
        this.token = token;
        this.mapAccountInformation = mapAccountInformation;
    }*/

    public UpdateAssignmentPelayoBatch(List<String> orderIds, String type) {
        this.listOrderIds = orderIds;
        this.type = type;
    }

    /**
     * @description Returns the iterable collection of Order IDs to be processed by the batch.
     * @param BC The Database.BatchableContext for this batch execution.
     * @return An Iterable of String Order IDs.
     */
    public Iterable<String> start(Database.BatchableContext BC) {
        return this.listOrderIds;
    }

    /**
     * @description Executes the Pelayo assignment update callout for each batch scope of Order IDs.
     * @param BC The Database.BatchableContext for this batch execution.
     * @param scope The list of Order ID strings to process in this batch chunk.
     */
    public void execute(Database.BatchableContext BC, List<String> scope) {

        PelayoWebServiceController.callPutEncargoPelayoService(scope, type);
        /*List<Order> ordersToUpdate = new List<Order>();
        for(Order encargo : scope){

            String requestBody = PelayoOutBoundStrucuture.createJSON(PelayoWebServiceController.setCaseInfoFromOrder(encargo), new List<Order>{encargo}, mapAccountInformation, type);
            System.debug('Request Body: ' + PelayoWebServiceController.debugPrettyPrintJSON(requestBody));

            PelayoWebServiceController.UpdateAssignmentPelayoResponse serviceResponse = PelayoWebServiceController.updateAssignmentPelayoService(config.Endpoint__c, token, requestBody);
            if(serviceResponse.success){
                for(PelayoWebServiceController.EncargoResponse serviceEncargo : serviceResponse.encargos){
                    ordersToUpdate.add(PelayoWebServiceController.setOrderWithResponseInfo(encargo, serviceEncargo));
                    PelayoWebServiceController.sendResponseEvent(serviceEncargo.success, encargo.Id, serviceEncargo.message);
                }
            }
            PelayoWebServiceController.sendResponseEvent(serviceResponse.success, encargo.CaseNumber__c, serviceResponse.message);
        }

        if(!ordersToUpdate.isEmpty()){
            update ordersToUpdate;
        }*/
    }

    /**
     * @description Performs any post-processing logic after all batch chunks have been executed.
     * @param BC The Database.BatchableContext for this batch execution.
     */
    public void finish(Database.BatchableContext BC) {
        // Implement any post-processing logic here
    }
}