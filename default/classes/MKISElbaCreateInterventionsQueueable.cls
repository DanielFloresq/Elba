/**
 * @description       : Queueable job to create MKIS interventions for a list of Orders.
 *                      Runs in a separate transaction so that prior DML (e.g. Stakeholder MKISId__c)
 *                      is already committed before the callouts are made.
 * @author            : Daniel Flores
 * @group             : MKIS Integration
 * @last modified on  : 05-05-2026
 * @last modified by  : Daniel Flores
**/
public without sharing class MKISElbaCreateInterventionsQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> orderIds;

    public MKISElbaCreateInterventionsQueueable(List<Id> orderIds) {
        this.orderIds = orderIds;
    }

    public void execute(QueueableContext context) {
        MKISElbaInterventionHandler.createInterventionsForOrders(orderIds);
    }
}