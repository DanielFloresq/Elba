import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; 
import getDocuments from '@salesforce/apex/DocumentManagerController.getDocuments';
import deleteDocuments from '@salesforce/apex/DocumentManagerController.deleteDocuments';
import sendEmailWithDocuments from '@salesforce/apex/DocumentManagerController.sendEmailWithDocuments';
import searchTasks from '@salesforce/apex/DocumentManagerController.searchTasks';
import searchCases from '@salesforce/apex/DocumentManagerController.searchCases';
import reassignDocuments from '@salesforce/apex/DocumentManagerController.reassignDocuments';
import getTaskFieldLabels from '@salesforce/apex/DocumentManagerController.getTaskFieldLabels';
import SEARCH from "@salesforce/label/c.Search";
import SEARCHDOCUMENTS from "@salesforce/label/c.SearchDocuments";
import CREATIONDATE from "@salesforce/label/c.CreationDate";
import REASSIGNSELECTEDDOCUMENTSTOOTHERCLAIMS from "@salesforce/label/c.ReassignSelectedDocumentsToOtherClaims";
import VIEWDOCUMENT from "@salesforce/label/c.ViewDocument";
import DOWNLOADSELECTEDFILES from "@salesforce/label/c.DownloadSelectedDocuments";
import SENDINGSELECTEDDOCUMENTS from "@salesforce/label/c.SendingSelectedDocuments";
import DELETESELECTEDDOCUMENTS from "@salesforce/label/c.DeleteSelectedDocuments";
import NAMEF from "@salesforce/label/c.NameF";
import TYPEF from "@salesforce/label/c.TypeF";
import CREATEDBY from "@salesforce/label/c.CreatedBy";
import REASSIGN from "@salesforce/label/c.Reassign";
import REASSIGNDOCUMENTS from "@salesforce/label/c.ReassignDocuments";
import CANCEL from "@salesforce/label/c.CancelF";
import DOCUMENT_CHANNEL from '@salesforce/messageChannel/documentChannel__c';
import ErrorApplyingTemplate  from "@salesforce/label/c.ErrorApplyingTemplate";
import InvalidEmailAddress  from "@salesforce/label/c.InvalidEmailAddress";
import MissingRecipient  from "@salesforce/label/c.MissingRecipient";
import AddAtLeastOneEmailAddressInTheToField  from "@salesforce/label/c.AddAtLeastOneEmailAddressInTheToField";
import ErrorSendingEmail  from "@salesforce/label/c.ErrorSendingEmail";
import ContactTheAdministratorIfTheProblemPersists  from "@salesforce/label/c.ContactTheAdministratorIfTheProblemPersists";
import Error from "@salesforce/label/c.Error";
import SelectAtLeastOneDocument  from "@salesforce/label/c.SelectAtLeastOneDocument";
import EmailSentSuccessfully  from "@salesforce/label/c.EmailSentSuccessfully";
import Success  from "@salesforce/label/c.Success";
import DocumentSuccessfullyDeleted   from "@salesforce/label/c.DocumentSuccessfullyDeleted";
import ErrorDeletingDocuments   from "@salesforce/label/c.ErrorDeletingDocuments";
import SelectDocumentsAndTargetBeforeConfirming   from "@salesforce/label/c.SelectDocumentsAndTargetBeforeConfirming";
import DocumentsSuccessfullyReassigned    from "@salesforce/label/c.DocumentsSuccessfullyReassigned";
import ErrorReassigningDocuments     from "@salesforce/label/c.ErrorReassigningDocuments";
import DocumentalType    from "@salesforce/label/c.DocumentalType";
import CommentsF     from "@salesforce/label/c.CommentsF";
import RelatedCase     from "@salesforce/label/c.RelatedCase";
import getOrdersByCase from '@salesforce/apex/DocumentManagerController.getOrdersByCase';
import { MessageContext, subscribe } from 'lightning/messageService';
import CASEF from "@salesforce/label/c.CaseF";
import SelectedTask from "@salesforce/label/c.SelectedTask";
import RelatedRecord from "@salesforce/label/c.RelatedRecord";
import SearchTasks from "@salesforce/label/c.SearchTasks";
import SearchTasksPlaceholder from "@salesforce/label/c.SearchTasksPlaceholder";
import SearchTasksExample from "@salesforce/label/c.SearchTasksExample";
import ChooseOrder from "@salesforce/label/c.ChooseOrder";
import LoadingOrders from "@salesforce/label/c.LoadingOrders";
import SearchResults from "@salesforce/label/c.SearchResults";
import SearchingTasks from "@salesforce/label/c.SearchingTasks";
import Searching from "@salesforce/label/c.Searching";
import NoTasksFound from "@salesforce/label/c.NoTasksFound";
import ConfirmDeletion from "@salesforce/label/c.ConfirmDeletion";
import ConfirmDeleteMessage from "@salesforce/label/c.ConfirmDeleteMessage";
import Yes from "@salesforce/label/c.Yes";
import ContactRecord from "@salesforce/label/c.ContactRecord";

import { NavigationMixin } from 'lightning/navigation';

export default class DocumentManager extends NavigationMixin(LightningElement) {
    @api recordId;
    @track documents = [];
    @track filteredDocuments = [];
    selectedRows = [];
    searchKeyTarget = '';
    subscription = null;
    @track showEmailModal = false;
    @track emailFiles = [];
    @track showDeleteConfirmModal = false;
    @track documentsToDelete = [];
    @track selectedTask = null; // Task selecionada
    @wire(MessageContext)
    messageContext;

    @track searchKey = '';
    @track tasks;
    @track loading = false;
    @track noTasksFound = false;
    @track taskFieldLabels = {};

    columns2 = [
        { label: 'Subject', fieldName: 'Subject', type: 'text', cellAttributes: { class: 'slds-text-title' } },
        { label: RelatedRecord, fieldName: 'RelatedRecord', type: 'text' },
        { label: 'Status', fieldName: 'Status', type: 'text' },
        { label: 'Data Vencimento', fieldName: 'ActivityDate', type: 'date' },
        /* { label: 'Prioridade', fieldName: 'Priority', type: 'text' }, */
        {
            type: 'button',
            typeAttributes: {
                label: 'Selecionar',
                name: 'select',
                title: 'Selecionar Task',
                variant: 'brand',
                class: 'select-button'
            },
            cellAttributes: {
                alignment: 'center'
            }
        }
    ];


    sortBy = '';
    sortDirection = 'asc';

    searchResults = [];
    selectedTarget = null;
    isToShowOrders = false;
    showSpinner = false;

    label = {
        SEARCH,
        SEARCHDOCUMENTS,
        CREATIONDATE,
        REASSIGNSELECTEDDOCUMENTSTOOTHERCLAIMS,
        VIEWDOCUMENT,
        DOWNLOADSELECTEDFILES,
        SENDINGSELECTEDDOCUMENTS,
        DELETESELECTEDDOCUMENTS,
        NAMEF,
        TYPEF,
        CREATEDBY,
        REASSIGN,
        CASEF,
        REASSIGNDOCUMENTS,
        CANCEL,
        ErrorApplyingTemplate  ,
        InvalidEmailAddress ,
        MissingRecipient  ,
        AddAtLeastOneEmailAddressInTheToField  ,
        ErrorSendingEmail  ,
        ContactTheAdministratorIfTheProblemPersists  ,
        Error ,
        SelectAtLeastOneDocument  ,
        EmailSentSuccessfully  ,
        Success  ,
        DocumentSuccessfullyDeleted   ,
        ErrorDeletingDocuments ,
        SelectDocumentsAndTargetBeforeConfirming,
        DocumentsSuccessfullyReassigned  ,
        ErrorReassigningDocuments    ,
        DocumentalType,
        CommentsF,
        RelatedCase,
        SelectedTask,
        RelatedRecord,
        SearchTasks,
        SearchTasksPlaceholder,
        SearchTasksExample,
        ChooseOrder,
        LoadingOrders,
        SearchResults,
        SearchingTasks,
        Searching,
        NoTasksFound,
        ConfirmDeletion,
        ConfirmDeleteMessage,
        Yes,
        ContactRecord

    };

  

    
    matchingInfo = {
        primaryField: { fieldPath: 'CaseNumber' }
    };

    matchingInfoTask = {
        primaryField: { fieldPath: 'Subject' }
    };

    matchingInfotContact = {
        primaryField: { fieldPath: 'Name' }
    };



    displayInfo = {
        primaryField: 'CaseNumber'
    };

    displayInfoTask = {
        primaryField: 'Subject'
    };

    displayInfoContact = {
        primaryField: 'Name'
    };


    showReassignModal = false;
    selectedTargetIds = [];
    selectedTargetId;
    @track selectedOrderId;
    @track orders = [];
    targetObject = 'Case';
    get isOrderOrCase(){
        return this.recordId.startsWith('500') || this.recordId.startsWith('801') ;
    }

    get isTask(){
        return this.recordId.startsWith('00T');
    }

    get isContact(){
        return this.recordId.startsWith('003');
    }

    get taskCount(){
        return this.tasks ? this.tasks.length : 0;
    }

    get selectedTaskLabel(){
        return this.selectedTask ? `${SelectedTask}` : '';
    }

    get subjectLabel(){
        return this.taskFieldLabels.Subject || 'Subject';
    }

    get statusLabel(){
        return this.taskFieldLabels.Status || 'Status';
    }

    get dueDateLabel(){
        return this.taskFieldLabels.ActivityDate || 'Due Date';
    }

    get priorityLabel(){
        return this.taskFieldLabels.Priority || 'Priority';
    }
   
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
    handleSearchChange2(event) {
        this.searchKey = event.target.value;
        this.fetchTasks();
    }

    fetchTasks() {
        this.loading = true;
        this.noTasksFound = false;
        searchTasks({ searchKey: this.searchKey })
            .then(result => {
                this.tasks = result;
                this.noTasksFound = result && result.length === 0;
                this.loading = false;
            })
            .catch(error => {
                console.error(error);
                this.loading = false;
            });
    }

    handleRowAction2(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'select') {
            this.selectedTask = row;          // Task selecionada
            this.targetRecordId = row.Id;     // Guarda o Id
            this.tasks = null; 
            this.selectedTargetId = row.Id;               // Esconde a lista
            console.log('Task selecionada:', row);
            // Dispara evento para o pai, se necessário
            const selectedEvent = new CustomEvent('taskselected', { detail: row });
            this.dispatchEvent(selectedEvent);
        }
    }




    columns = [
        {
            label: this.label.NAMEF,
            fieldName: 'viewLink',   
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'Title' }, 
                target: '_self'                
            },
            sortable: true
        },
        { label: this.label.TYPEF, fieldName: 'FileType', type: 'text', sortable: true },
        { label: 'Fase Documental', fieldName: 'DocumentalFase', type: 'text', sortable: true },
        { label: this.label.DocumentalType, fieldName: 'DocumentalType', type: 'text', sortable: true },
        { label: this.label.CommentsF, fieldName: 'Comments', type: 'text', sortable: true },
        { label: this.label.RelatedRecord , fieldName: 'OrderRelated', type: 'text', sortable: true },
        { label: this.label.CREATIONDATE, fieldName: 'CreatedDate', type: 'date', sortable: true },
        { label: this.label.CREATEDBY, fieldName: 'CreatedByName', type: 'text', sortable: true },
        {
            type: 'action',
            typeAttributes: { rowActions: [
                { label: this.label.VIEWDOCUMENT, name: 'view' }
            ]}
        }
    ];
    

    connectedCallback() {
        this.loadDocuments();
        this.registerMessageListener();
        this.loadTaskFieldLabels();
    }

    loadTaskFieldLabels() {
        getTaskFieldLabels()
            .then(result => {
                this.taskFieldLabels = result;
                this.updateColumns2Labels();
            })
            .catch(error => {
                console.error('Erro ao carregar labels dos campos da Task:', error);
            });
    }

    updateColumns2Labels() {
        this.columns2 = [
            { label: this.taskFieldLabels.Subject || 'Subject', fieldName: 'Subject', type: 'text', cellAttributes: { class: 'slds-text-title' } },
            { label: this.label.RelatedRecord, fieldName: 'RelatedRecord', type: 'text' },
            { label: this.taskFieldLabels.Status || 'Status', fieldName: 'Status', type: 'text' },
            { label: this.taskFieldLabels.ActivityDate || 'Data Vencimento', fieldName: 'ActivityDate', type: 'date' },
            { label: this.taskFieldLabels.Priority || 'Prioridade', fieldName: 'Priority', type: 'text' },
            {
                type: 'button',
                typeAttributes: {
                    label: 'Selecionar',
                    name: 'select',
                    title: 'Selecionar Task',
                    variant: 'brand',
                    class: 'select-button'
                },
                cellAttributes: {
                    alignment: 'center'
                }
            }
        ];
    }

    handleTargetChange(event) {
        this.selectedTargetId = event.detail.recordId;
    
        if (this.selectedTargetId) {
            this.showSpinner = true; 
            this.isToShowOrders = false;
            this.orders = [];
    
            getOrdersByCase({ caseId: this.selectedTargetId })
                .then(result => {
                    this.orders = result.map(order => ({
                        label: order.OrderNumber,
                        value: order.Id
                    }));
                    this.isToShowOrders = this.orders.length > 0;
                })
                .catch(error => {
                    console.error(error);
                    this.orders = [];
                    this.isToShowOrders = false;
                })
                .finally(() => {
                    this.showSpinner = false; 
                });
        } else {
            this.isToShowOrders = false;
            this.orders = [];
        }
    }

    handleOrderChange(event) {
        this.selectedOrderId = event.detail.value;
    }
    registerMessageListener() {
        if (!this.subscription && this.messageContext) {
            this.subscription = subscribe(
                this.messageContext,
                DOCUMENT_CHANNEL,
                (message) => {
                    try {
                        if (message && message.refresh) {
                            this.loadDocuments();
                        }
                    } catch(e) {
                        console.error('Erro ao tratar mensagem:', e);
                    }
                }
            );
        }
    }


    handleMessage(message) {
        console.log('Mensagem recebida:', message);
        this.loadDocuments(); 
    }


    loadDocuments() {
        getDocuments({ recordId: this.recordId })
            .then(result => {
                
                this.selectedRows = [];
    
                if (result && result.length > 0) {
                   
                    const newDocs = result.map(doc => ({ ...doc }));
                    this.documents = newDocs;
                    this.filteredDocuments = [...newDocs];
                } else {
                    
                    this.documents = [];
                    this.filteredDocuments = [];
                }
            })
            .catch(error => {
                console.error('Erro ao carregar documentos:', error);
               
                this.documents = [];
                this.filteredDocuments = [];
            });
    }
    

    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows;
    }

    handleDownload() {
        this.selectedRows.forEach(row => {
            window.open(`/sfc/servlet.shepherd/document/download/${row.ContentDocumentId}`);
        });
    }

    handleSendEmail() {
        if (this.selectedRows.length === 0) {
            this.showToast('Erro', this.label.SelectAtLeastOneDocument, 'error');
            return;
        }
        const ids = this.selectedRows.map(r => r.ContentDocumentId);
        sendEmailWithDocuments({ documentIds: ids, recordId: this.recordId })
            .then(() => this.showToast(this.label.Success, this.label.EmailSentSuccessfully, 'success'))
            .catch(err => {
                console.error(err);
                this.showToast(this.label.Error, this.label.ErrorSendingEmail, 'error');
            });
    }

    handleDelete() {
        if (this.selectedRows.length === 0) {
            this.showToast(this.label.Error, this.label.SelectAtLeastOneDocument, 'error');
            return;
        }
    
      
        this.documentsToDelete = [...this.selectedRows];
    
        
        this.showDeleteConfirmModal = true;
    }

    

    handleConfirmDelete() {
        const ids = this.documentsToDelete.map(doc => doc.ContentDocumentId);
    
        deleteDocuments({ documentIds: ids })
            .then(() => {
                this.loadDocuments();
                this.selectedRows = [];
                this.showToast(this.label.Success, this.label.DocumentSuccessfullyDeleted, 'success');
            })
            .catch(err => {
                console.error(err);
                this.showToast(this.label.Error, this.label.ErrorDeletingDocuments, 'error');
            })
            .finally(() => {
                this.loadDocuments();
                this.showDeleteConfirmModal = false;
                this.documentsToDelete = [];
            });
    }

    handleCancelDelete() {
        this.showDeleteConfirmModal = false;
        this.documentsToDelete = [];
    }

    handleOpenEmailModal() {
        if (this.selectedRows.length === 0) {
            this.showToast(this.label.Error, this.label.SelectAtLeastOneDocument, 'error');
            return;
        }

        const documentIds = this.selectedRows.map(r => r.ContentDocumentId);

        this.emailFiles = this.selectedRows.map(r => ({
            id: r.ContentDocumentId,
            name: r.Title
        }));

        this.showEmailModal = true;
    }

    handleCloseEmailModal() {
        this.showEmailModal = false;
    }

    handleEmailSent() {
        this.showEmailModal = false;
        this.showToast(this.label.Success, this.label.EmailSentSuccessfully, 'success');
    }

    handleSearchChange(event) {
        this.searchKeyTarget = event.target.value;

        if (this.searchKeyTarget.length < 2) {
            this.searchResults = [];
            return;
        }

        searchCases({ searchKey: this.searchKeyTarget })
            .then(result => {
                this.searchResults = result;
            });
    }

    handleSelect(event) {
        const id = event.currentTarget.dataset.id;
        const label = event.currentTarget.dataset.label;

        this.selectedTarget = { id, label }; 
        this.searchResults = [];
        this.searchKeyTarget = '';
        
    }
    
    handleRemove(event) {
        const id = event.detail.name;
        this.selectedTargets = this.selectedTargets.filter(t => t.id !== id);
    }
    
    get disableConfirm() {
        return !this.selectedTargetId;
    }

    get confirmIfIsNull() {
        return this.orders != [] && this.orders.length() > 0 ;
    }

    closeReassignModal() {
        this.showReassignModal = false;
        this.selectedTargetId = null;
        this.isToShowOrders = false;
        this.orders = [];


        /* this.tasks = [];      */       
        this.selectedTask = null; 
        this.targetRecordId = null;
        this.searchKey = '';
        this.loading = false;
    
    
    }

    openEmail() {
        const event = new CustomEvent('openEmailModalEvent', {
            bubbles: true,
            composed: true,
            detail: { documentIds: this.selectedRows.map(r => r.ContentDocumentId) }
        });
        this.dispatchEvent(event);
    }

    handleReassign() {
        if (!this.selectedRows.length) {
            this.showToast(this.label.Error, this.label.SelectAtLeastOneDocument, 'error');
            return;
        }
        this.selectedTargetId = null;
        this.showReassignModal = true;
    }

    handleSearch(event) {
        this.searchKeyTarget = event.target.value.toLowerCase();
        this.filteredDocuments = this.documents.filter(doc =>
            Object.values(doc).some(val =>
                String(val).toLowerCase().includes(this.searchKeyTarget)
            )
        );
    }

    onHandleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData(this.sortBy, this.sortDirection);
    }

    sortData(fieldName, direction) {
        let parseData = [...this.filteredDocuments];
        parseData.sort((a, b) => {
            let valA = a[fieldName] ? a[fieldName] : '';
            let valB = b[fieldName] ? b[fieldName] : '';
            return direction === 'asc' ? (valA > valB ? 1 : -1) : (valA > valB ? -1 : 1);
        });
        this.filteredDocuments = parseData;
    }

    @track showFileModal = false;
    @track currentDocumentId;

    handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;

        if (action === 'view') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: row.ContentDocumentId,
                    objectApiName: 'ContentDocument',
                    actionName: 'view'
                }
            });
        } else if (action === 'details') {
            
        } else if (action === 'navigate') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    objectApiName: 'Sinistro__c',
                    actionName: 'view'
                }
            });
        }
    }
    
    closeFileModal() {
        this.showFileModal = false;
        this.currentDocumentId = null;
    }

    confirmReassign() {
        if (!this.selectedRows.length || !this.selectedTargetId  ) {
            this.showToast(this.label.Error, this.label.SelectDocumentsAndTargetBeforeConfirming, 'error');
            return;
        }

        const documentIds = this.selectedRows.map(r => r.ContentDocumentId);
        const targetRecordId = this.selectedTargetId;
        const recordId = this.recordId;
        const orderId = this.selectedOrderId ;

        reassignDocuments({
            documentIds,
            targetRecordId, 
            recordId,
            orderId
        })
        .then(() => {
            this.loadDocuments();
            this.closeReassignModal();
            this.showToast(this.label.Success, this.label.DocumentsSuccessfullyReassigned, 'success');
        })
        .catch(error => {
            console.error(error);
            this.showToast(this.label.Error, this.label.ErrorReassigningDocuments, 'error');
        });
    }

}