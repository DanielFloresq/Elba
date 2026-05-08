import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendEmailWithDocuments from '@salesforce/apex/DocumentManagerController.sendEmailWithDocuments';
import getEmailTemplates from '@salesforce/apex/DocumentManagerController.getEmailTemplates';
import getOrgWideEmails from '@salesforce/apex/DocumentManagerController.getOrgWideEmails';
import applyEmailTemplate from '@salesforce/apex/DocumentManagerController.applyEmailTemplate';
import SENDEMAILF from "@salesforce/label/c.SendEmailF";
import TOF from "@salesforce/label/c.ToF";
import EMAILTEMPLATE from "@salesforce/label/c.EmailTemplate";
import SUBJECTF from "@salesforce/label/c.SubjectF";
import SELECTEDATTACHMENTS from "@salesforce/label/c.SelectedAttachments";
import SENDF from "@salesforce/label/c.SendF";
import CANCELF from "@salesforce/label/c.CancelF";
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
import USER_ID from '@salesforce/user/Id';
import getCurrentUserEmail from '@salesforce/apex/DocumentManagerController.getCurrentUserEmail';


export default class EmailComposer extends LightningElement {
    @api recordId;
    @api files = []; // [{id, name}]

    @track subject = '';
    @track body = '';
    @track isSending = false;

    // inputs atuais
    @track toInput = '';
    @track ccInput = '';
    @track bccInput = '';

    // listas de emails (pills)
    @track toList = [];
    @track ccList = [];
    @track bccList = [];

    // templates
    @track templateOptions = [];
    @track selectedTemplateId;

    @track fromOptions = [];
    @track selectedFrom;
    @track isFromLocked = true;



    label = {
        SENDEMAILF,
        TOF,
        EMAILTEMPLATE,
        SUBJECTF,
        SELECTEDATTACHMENTS,
        SENDF,
        CANCELF,
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
    };



    // expandir corpo
    @track isBodyExpanded = false;

    connectedCallback() {
        this.loadTemplates();
        this.loadOrgWideEmails();
    }

    loadOrgWideEmails() {
        this.fromOptions = [];
    
        getCurrentUserEmail()
            .then(userEmail => {
                // Adiciona o próprio utilizador
                this.fromOptions.push({
                    label: userEmail,
                    value: 'USER'
                });
    
                return getOrgWideEmails();
            })
            .then(result => {
                if (result && result.length > 0) {
                    result.forEach(owe => {
                        this.fromOptions.push({
                            label: `${owe.DisplayName} <${owe.Address}>`,
                            value: owe.Id
                        });
                        this.selectedFrom = owe.Id;
                    });
                }
    
                // Só bloqueia se existir apenas 1 opção (user)
                this.isFromLocked = this.fromOptions.length === 1;
                this.fromOptions = [...this.fromOptions];
                // ✅ Define o valor **depois** de preencher fromOptions
              /*   this.selectedFrom = 'USER'; */
            })
            .catch(error => {
                console.error('Erro a carregar From options', error);
            });
    }


    handleFromChange(event) {
        this.selectedFrom = event.detail.value;
    }

    // --------- TEMPLATES ---------

    loadTemplates() {
        getEmailTemplates()
            .then(result => {
                this.templateOptions = result.map(t => ({
                    label: t.Name,
                    value: t.Id
                }));
            })
            .catch(error => {
                console.error(error);
            });
    }

    handleTemplateChange(event) {
        this.selectedTemplateId = event.detail.value;

        if (!this.selectedTemplateId) {
            return;
        }

        applyEmailTemplate({
            templateId: this.selectedTemplateId,
            recordId: this.recordId
        })
        .then(result => {
            if (result) {
                if (result.subject) {
                    this.subject = result.subject;
                }
                if (result.htmlBody) {
                    this.body = result.htmlBody;
                }
            }
        })
        .catch(error => {
            console.error(error);
            this.showErrorToast(this.label.ErrorApplyingTemplate, this.label.TheSelectedTemplateCouldNotBeLoaded);
        });
    }

    // --------- INPUTS ---------

    handleToInputChange(event) {
        this.toInput = event.target.value;
    }

    handleCcInputChange(event) {
        this.ccInput = event.target.value;
    }

    handleBccInputChange(event) {
        this.bccInput = event.target.value;
    }

    handleToKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.addEmailToList('to');
        }
    }

    handleCcKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.addEmailToList('cc');
        }
    }

    handleBccKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.addEmailToList('bcc');
        }
    }

    // --------- PILLS ---------

    addEmailToList(type) {
        let value;
        if (type === 'to') value = this.toInput;
        if (type === 'cc') value = this.ccInput;
        if (type === 'bcc') value = this.bccInput;

        const email = (value || '').trim();
        if (!email) {
            return;
        }

        if (!this.isValidEmail(email)) {
            this.showErrorToast(this.label.InvalidEmailAddress);
            return;
        }

        if (type === 'to') {
            if (!this.toList.includes(email)) {
                this.toList = [...this.toList, email];
            }
            this.toInput = '';
        } else if (type === 'cc') {
            if (!this.ccList.includes(email)) {
                this.ccList = [...this.ccList, email];
            }
            this.ccInput = '';
        } else if (type === 'bcc') {
            if (!this.bccList.includes(email)) {
                this.bccList = [...this.bccList, email];
            }
            this.bccInput = '';
        }
    }

    handleRemoveTo(event) {
        const email = event.target.name;
        this.toList = this.toList.filter(e => e !== email);
    }

    handleRemoveCc(event) {
        const email = event.target.name;
        this.ccList = this.ccList.filter(e => e !== email);
    }

    handleRemoveBcc(event) {
        const email = event.target.name;
        this.bccList = this.bccList.filter(e => e !== email);
    }

    // --------- SUBJECT / BODY ---------

    handleSubjectChange(event) {
        this.subject = event.target.value;
    }

    handleBodyChange(event) {
        this.body = event.target.value;
    }

    // --------- EXPANDIR CORPO ---------

    get bodyContainerClass() {
        return this.isBodyExpanded
            ? 'body-container body-container_expanded'
            : 'body-container';
    }

    get expandIcon() {
        return this.isBodyExpanded ? 'utility:contract_alt' : 'utility:expand_alt';
    }

    toggleExpandBody() {
        this.isBodyExpanded = !this.isBodyExpanded;
    }

    // --------- ENVIO ---------

    handleSend() {
        if (!this.toList.length) {
            this.showErrorToast(this.label.MissingRecipient, this.label.AddAtLeastOneEmailAddressInTheToField);
            return;
        }

        const orgWideEmailId =  this.selectedFrom !== 'USER' ? this.selectedFrom : null;

        this.isSending = true;
        const documentIds = this.files.map(f => f.id);

        sendEmailWithDocuments({
            recordId: this.recordId,
            toAddresses: this.toList,
            ccAddresses: this.ccList,
            bccAddresses: this.bccList,
            subject: this.subject,
            body: this.body,
            documentIds: documentIds,
            orgWideEmailId: orgWideEmailId
        })
        .then(() => {
            this.isSending = false;
            this.dispatchEvent(new CustomEvent('sent'));
        })
        .catch(error => {
            this.isSending = false;
            console.error(error);
            this.showErrorToast(this.label.ErrorSendingEmail, this.label.ContactTheAdministratorIfTheProblemPersists);
        });
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    // --------- UTILITÁRIOS ---------

    isValidEmail(email) {
        const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return re.test(email);
    }

    showErrorToast(title, message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant: 'error'
            })
        );
    }
}