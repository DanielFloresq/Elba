/**
 * @description       : 
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 24-02-2026
 * @last modified by  : Daniel Flores
**/
trigger OrderTrigger on Order (after insert, after update) {
    OrderTriggerHandler.run();
}