/**
 * @description       : Trigger on Incident for MKIS ELBA integration.
 *                      Creates/Updates incidences in the MKIS ELBA API.
 * @author            : Daniel Flores
 * @group             : MKIS Integration
 * @last modified on  : 26-03-2026
 * @last modified by  : Daniel Flores
**/
trigger IncidentTrigger on Incident (after insert, after update) {
    IncidentTriggerHandler.run();
}