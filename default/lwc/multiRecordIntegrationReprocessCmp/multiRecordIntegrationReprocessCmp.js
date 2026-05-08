/**
 * @description       : 
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 04-03-2026
 * @last modified by  : Daniel Flores
**/
import { LightningElement, api, track } from 'lwc';
import getObjectType from '@salesforce/apex/MultiRecordIntegrationController.getObjectType';
import reprocessMultipleRecords from '@salesforce/apex/MultiRecordIntegrationController.reprocessMultipleRecords';
import getJobDetails from '@salesforce/apex/MultiRecordIntegrationController.getJobDetails';
import getRecords from '@salesforce/apex/MultiRecordIntegrationController.getRecords';
import getAllRecords from '@salesforce/apex/MultiRecordIntegrationController.getAllRecords';
import Reprocess_Datatable_Case_CaseNumber from '@salesforce/label/c.Reprocess_Datatable_Case_CaseNumber';
import Reprocess_Datatable_Case_ContactName from '@salesforce/label/c.Reprocess_Datatable_Case_ContactName';
import Reprocess_Datatable_Case_Status from '@salesforce/label/c.Reprocess_Datatable_Case_Status';
import Reprocess_Datatable_Case_Descritivo from '@salesforce/label/c.Reprocess_Datatable_Case_Descritivo';
import Reprocess_Datatable_Order_CodigoServico from '@salesforce/label/c.Reprocess_Datatable_Order_CodigoServico';
import Reprocess_Datatable_Order_Type from '@salesforce/label/c.Reprocess_Datatable_Order_Type';
import Reprocess_Datatable_Order_Status from '@salesforce/label/c.Reprocess_Datatable_Order_Status';
import Reprocess_Datatable_Order_Descritivo from '@salesforce/label/c.Reprocess_Datatable_Order_Descritivo';

import Reprocess_Component_Title from '@salesforce/label/c.Reprocess_Component_Title';
import Reprocess_Button_Cancel from '@salesforce/label/c.Reprocess_Button_Cancel';
import Reprocess_Button_Back from '@salesforce/label/c.Reprocess_Button_Back';
import Reprocess_Button_Next from '@salesforce/label/c.Reprocess_Button_Next';
import Reprocess_Button_Finish from '@salesforce/label/c.Reprocess_Button_Finish';
import Reprocess_Button_ExecuteBatch from '@salesforce/label/c.Reprocess_Button_ExecuteBatch';
import Reprocess_Label_ObjectType from '@salesforce/label/c.Reprocess_Label_ObjectType';
import Reprocess_Placeholder_ObjectType from '@salesforce/label/c.Reprocess_Placeholder_ObjectType';
import Reprocess_Alias_Order from '@salesforce/label/c.Reprocess_Alias_Order';
import Reprocess_Alias_Case from '@salesforce/label/c.Reprocess_Alias_Case';
import Reprocess_Alias_Notification from '@salesforce/label/c.Reprocess_Alias_Notification';
import Reprocess_Alias_Service from '@salesforce/label/c.Reprocess_Alias_Service';
import Reprocess_Ongoing from '@salesforce/label/c.Reprocess_Ongoing';
import Reprocess_finished from '@salesforce/label/c.Reprocess_finished';
import Reprocess_failed from '@salesforce/label/c.Reprocess_failed';
import Reprocess_Select_Record from '@salesforce/label/c.Reprocess_Select_Record';
import Reprocess_Select_One_Object from '@salesforce/label/c.Reprocess_Select_One_Object';


const caseColumns = [
    { label: Reprocess_Datatable_Case_CaseNumber, fieldName: 'caseNumber' }, 
    { label: Reprocess_Datatable_Case_ContactName, fieldName: 'contactName' }, 
    { label: Reprocess_Datatable_Case_Status, fieldName: 'status' }, 
    { label: Reprocess_Datatable_Case_Descritivo, fieldName: 'descritivoDaUltimaIntegracao', wrapText: true },
];


const serviceColumns = [
    { label: Reprocess_Datatable_Case_CaseNumber, fieldName: 'caseNumber' }, 
    { label: Reprocess_Datatable_Case_Status, fieldName: 'status' },
    { label: Reprocess_Datatable_Case_Descritivo, fieldName: 'descritivoDaUltimaIntegracao', wrapText: true }, 
];



const orderColumns = [
    { label: Reprocess_Datatable_Order_CodigoServico, fieldName: 'codigoServico' }, 
    { label: Reprocess_Datatable_Order_Type, fieldName: 'type' },   
    { label: Reprocess_Datatable_Order_Status, fieldName: 'status' },   
    { label: Reprocess_Datatable_Order_Descritivo, fieldName: 'descritivoDaUltimaIntegracao', wrapText: true } 
];

const caseResultColumns = [
    { label: Reprocess_Datatable_Case_CaseNumber, fieldName: 'caseNumber' },
    { label: Reprocess_Datatable_Case_Descritivo, fieldName: 'descritivoDaUltimaIntegracao', wrapText: true },
];

const serviceResultColumns = [
    { label: Reprocess_Datatable_Case_CaseNumber, fieldName: 'caseNumber' },
    { label: Reprocess_Datatable_Case_Descritivo, fieldName: 'descritivoDaUltimaIntegracao', wrapText: true },
];


const orderResultColumns = [
    { label: Reprocess_Datatable_Order_CodigoServico, fieldName: 'codigoServico' },
    { label: Reprocess_Datatable_Order_Descritivo, fieldName: 'descritivoDaUltimaIntegracao', wrapText: true }
];

export default class MultiRecordIntegrationReprocessCmp extends LightningElement {
    @track componentTitle = Reprocess_Component_Title; 
    @track cancelButtonLabel = Reprocess_Button_Cancel; 
    @track backButtonLabel = Reprocess_Button_Back; 
    @track nextButtonLabel = Reprocess_Button_Next; 
    @track finishButtonLabel = Reprocess_Button_Finish; 
    @track executeBatchButtonLabel = Reprocess_Button_ExecuteBatch; 
    @track objectTypeLabel = Reprocess_Label_ObjectType; 
    @track objectTypePlaceholder = Reprocess_Placeholder_ObjectType; 
    @track availableObjectTypes = [
        { label: Reprocess_Alias_Order, value: 'Order' }, 
        { label: Reprocess_Alias_Case, value: 'Case' },
        { label: Reprocess_Alias_Service, value: 'Service' }
    ];
    @track runningMessage;

    
    @track showCancelButton;
    @track showBackButton;
    @track showFinishButton;
    @track showNextButton;
    @track showExecuteBatchButton;
    @track isLoading;
    @track showDatatable;
    @track showObjectTypeSelection;
    @track showProgressBar;
    @track isBatchRunning;
    @track showResults;

   
    @track currentPercentage;
    @track totalPercentage = 100;
    @track totalBatchSize;
    @track batchProcessedSize;
    @track batchJobId;
    @track batchDetails;
    @track recordsIdsArray;
    @track dataRecords;
    @track dataColumns;
    @track objectType;
    @track selectedRecords;


    connectedCallback() {
        this.setStage1();
    }

    ///////////////////////
    // Events
    ///////////////////////

    // This method is called when the user selects a type of object on the dropdown list
    handleTypeChange(event) {
        this.objectType = event.detail.value;
    }

    // This method is called when the user clicks on the "Voltar" button
    // It sets the component back to the stage 1
    handleBackClick(event) {
        this.setStage1();
    }

    // This method is called when the user clicks on the "Próximo" button
    // Set the component to the stage 2 only if there is a type of object selected
    handleNextClick(event) {
        if(this.objectType == null){
            alert(Reprocess_Select_One_Object);
            return;
        }
        else{
            this.setStage2();
        }
    }

    // This method is called when the user clicks on the "Reprocessar" button
    // Set the component to the stage 3 only if there are records selected
    handleExecuteBatchClick(event) {
        if(this.template.querySelector('lightning-datatable').getSelectedRows() == null || this.template.querySelector('lightning-datatable').getSelectedRows().length == 0){
            alert(Reprocess_Select_Record);
            return;
        }
        else{
            this.setStage3();
        }
    }

    // This method is called when the user clicks on the "Finalizar" button
    // It resets the component to its initial state
    handleFinishClick(event) {
        this.connectedCallback();
        this.isLoading = false;
    }


    // This method is called when the user clicks on the "Reprocessar" button
    // The batch is not called here. This method only fetches the batch details to be displayed on the progress bar
    fetchBatchDetails() {
        if (this.isBatchRunning) {
            this.runningMessage = Reprocess_Ongoing;
            getJobDetails({ jobId: this.batchJobId }).then(result => {
                this.batchDetails = JSON.parse(JSON.stringify(result));
                console.log(this.batchDetails[0].jobItemsProcessed);
                this.batchProcessedSize = this.batchDetails[0].jobItemsProcessed;
                this.totalBatchSize = this.batchDetails[0].totalJobItems;
                this.currentPercentage = (this.batchProcessedSize / this.totalBatchSize) * this.totalPercentage;
                console.log(this.currentPercentage);
                if (this.batchDetails[0].status == 'Completed') {
                    this.runningMessage = Reprocess_finished;
                    setTimeout(() => {
                        this.setStage4();
                    }, 1000);
                }
                else if (this.batchDetails[0].status == 'Failed') {
                    this.runningMessage = Reprocess_failed;
                    setTimeout(() => {
                        this.setStage4();
                    }, 1000);
                }
                else{
                    setTimeout(() => {
                        this.fetchBatchDetails();
                    }, 100);
                }
            });
        }
        else{
            this.setStage2();
        }
        this.isLoading = false;
    }

    // This method is called when the component is first loaded
    // It sets the initial state of the component, when the user is selecting the object type in the dropdown list
    setStage1() {
        this.objectType = null;
        this.showCancelButton = true;
        this.showBackButton = false;
        this.showFinishButton = false;
        this.showNextButton = true
        this.showExecuteBatchButton = false;
        this.isLoading = false;
        this.showDatatable = false;
        this.showObjectTypeSelection = true;
        this.showProgressBar = false;
        this.isBatchRunning = false;
        this.showFinishButton = false;
        this.showResults = false;
    }

    // This method is called when the user clicks on the next button
    // It sets the state of the component, when the user is selecting the records to be reprocessed, showing a datatable with the records of the selected object type
    // Also, it calls the getAllRecords Apex method to retrieve the records from the database
    // In this stage there are two buttons, the back button and the execute batch button
    setStage2(){
        this.showCancelButton = false;
        this.showBackButton = true;
        this.showFinishButton = false;
        this.showNextButton = false
        this.showExecuteBatchButton = true;
        this.isLoading = true;
        this.showDatatable = true;
        this.showObjectTypeSelection = false;
        this.showProgressBar = false;
        this.isBatchRunning = false;
        this.showFinishButton = false;
        this.showResults = false;
        this.dataColumns = this.objectType == 'Case' ? caseColumns : this.objectType == 'Order' ? orderColumns : this.objectType == 'Service' ? serviceColumns : [];
        getAllRecords({ recordType: this.objectType }).then(result => {
            this.dataRecords = JSON.parse(JSON.stringify(result));
            this.isLoading = false;
        });
    }

    // This method is called when the user clicks on the execute batch button
    // It sets the state of the component, when the user is executing the batch job
    // Also, it calls the reprocessMultipleRecords Apex method to execute the batch job
    // In this stage there are two buttons, the back button and the finish button
    // There is also a progress bar that shows the progress of the batch job
    setStage3(){
        this.showCancelButton = false;
        this.showBackButton = false;
        this.showFinishButton = false;
        this.showNextButton = false
        this.showExecuteBatchButton = false;
        this.isLoading = true;
        this.showDatatable = false;
        this.showObjectTypeSelection = false;
        this.showProgressBar = true;
        this.isBatchRunning = true;
        this.showFinishButton = false;
        this.showResults = false;
        this.selectedRecords = JSON.stringify(this.template.querySelector('lightning-datatable').getSelectedRows().map(record => record.id));
        console.log(this.selectedRecords);
        console.log(this.objectType);
        if( this.objectType == 'Participação Rejeitada'){
            this.objectType = 'Case';
        }
        reprocessMultipleRecords({recordType: this.objectType, recordIds: this.selectedRecords}).then(result => {
            this.isLoading = false;
            console.log(JSON.parse(JSON.stringify(result)));
            this.batchJobId = JSON.parse(JSON.stringify(result));
            this.isBatchRunning = true;
            this.fetchBatchDetails();
        });
    }

    // This method is called when the batch job is completed
    // It sets the state of the component, when the user is viewing the results of the batch job
    // Also, it calls the getRecords Apex method to retrieve the records from the database
    // In this stage there is only one button, the finish button
    // The finish button will reset the component to the initial state
    setStage4(){
        this.showCancelButton = false;
        this.showBackButton = false;
        this.showFinishButton = false;
        this.showNextButton = false
        this.showExecuteBatchButton = false;
        this.isLoading = true;
        this.showDatatable = false;
        this.showObjectTypeSelection = false;
        this.showProgressBar = false;
        this.isBatchRunning = false;
        this.showFinishButton = true;
        this.showResults = true;
        if(this.objectType == 'Case'){
            this.dataColumns = caseResultColumns;
        }
        else if(this.objectType == 'Order'){
            this.dataColumns = orderResultColumns;
        }
        else if(this.objectType == 'Service'){
            this.dataColumns = caseResultColumns;
        }
        getRecords({ recordType: this.objectType, recordIds: this.selectedRecords }).then(result => {
            this.dataRecords = JSON.parse(JSON.stringify(result));
            this.isLoading = false;
        });
    }

}