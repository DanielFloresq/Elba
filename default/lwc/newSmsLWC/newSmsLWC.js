/**
 * @description       :
 * @author            : Afonso Duque
 * @group             :
 * @last modified on  : 09-04-2026
 * @last modified by  : Daniel Flores
**/
import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import sendSMSMessage from '@salesforce/apex/NewSmsController.sendSMSMessage';
import getCase from '@salesforce/apex/NewSmsController.getCase';
import getQuickTexts from '@salesforce/apex/NewSmsController.getQuickTexts';
import getPicklistValues from '@salesforce/apex/NewSmsController.getPicklistValues';

export default class NewSmsLWC extends LightningElement {

    @api recordId;

    phoneNumber = '';
    textMessage = '';
    quickTextsList = [];
    quickTextOptions = [];
    quickTextFolderOptions = [];
    quickTextValue = '';
    quickTextFolderValue = '';
    recipientOptions = [];
    recipientValue = '';
    disableQuickTexts = true;
    disableQuickTextsFolders = true;
    disableSendSms = true;
    case = {};
    quickTextFields = ['Contact.Phone', 'Contact.MobilePhone', 'OwnerId', 'RecordType.DeveloperName', 'GrandAccount__c'];
    isLoading = false;
    recipientObjectApiName = 'Comments__c';
    recipientFieldApiName = 'Recipient__c';

    connectedCallback() {
        this.loadQuickTexts();
        this.loadRecipientOptions();
    }

    loadRecipientOptions() {
        getPicklistValues({ objectApiName: this.recipientObjectApiName, fieldApiName: this.recipientFieldApiName })
            .then((data) => {
                this.recipientOptions = (data || []).map((option) => ({
                    label: option.label,
                    value: option.value
                }));

                this.recipientValue = '';

                this.updateSendButtonState();
            })
            .catch((error) => {
                this.error = error.body?.message || error.message;
                this.recipientOptions = [];
                this.recipientValue = '';
                this.updateSendButtonState();
            });
    }

     loadQuickTexts() {
        this.isLoading = true;
        getQuickTexts({ recordId: this.recordId })
            .then(data => {
                if (data) {
                    this.disableQuickTextsFolders = false;
                    this.disableQuickTexts = false;

                    this.quickTextsList = data.quickTextsList;

                    this.quickTextFolderOptions = data.foldersList.map(folder => {
                        return { label: folder.Name, value: folder.DeveloperName };
                    });
                    this.quickTextFolderOptions.unshift({ label: data.mainFolder.Name, value: data.mainFolder.DeveloperName });
                    this.quickTextFolderValue = data.mainFolder.DeveloperName;

                    this.quickTextOptions = this.quickTextsList
                        .filter(qt => qt.Folder.DeveloperName === this.quickTextFolderValue)
                        .map(qt => ({ label: qt.Name, value: qt.Message }));
                    this.quickTextOptions.unshift({ label: 'Nenhum', value: '' });

                    this.quickTextsList.forEach(qt => {
                        if (qt.Message && qt.Message.includes('{!')) {
                            const matches = qt.Message.matchAll(/\{!([^}]+)\}/g);
                            for (const match of matches) {
                                let fieldName = match[1];
                                if (fieldName.startsWith('Case.')) {
                                    fieldName = fieldName.replace('Case.', '');
                                }
                                this.quickTextFields.push(fieldName);
                            }
                        }
                    });

                }

                if (this.recordId) {
                    this.loadCase();
                }
            })
            .catch(error => {
                this.error = error.body?.message || error.message;
                this.disableQuickTextsFolders = true;
                this.quickTextOptions = undefined;
            }).finally(() => {
                this.isLoading = false;
                this.updateSendButtonState();
            });
    }

    loadCase() {
        const uniqueFields = [...new Set(this.quickTextFields)];
        this.isLoading = true;
        getCase({ recordId: this.recordId, fields: uniqueFields })
            .then(result => {
                this.case = result;
                /* let prefix = this.case?.Contact?.MobilePhone?.startsWith('+') ? '' : this.case?.Contact?.MobilePhone?.startsWith('9') ? '+351' : '+34';
                this.phoneNumber = prefix + this.case?.Contact?.MobilePhone || ''; */
            })
            .catch(error => {
                this.error = error.body?.message || error.message;
                this.disableQuickTextsFolders = true;
                this.quickTextOptions = undefined;
            }).finally(() => {
                this.isLoading = false;
                this.updateSendButtonState();
            });
    }

    handleChangePhoneNumber(event) {
        this.phoneNumber = event.detail?.value ?? event.target.value;
        this.updateSendButtonState();
    }

    handleChangeMessageText(event) {
        this.applyMessageText(event.detail?.value ?? event.target.value);
    }

    handleRecipientChange(event) {
        this.recipientValue = event.detail?.value ?? event.target.value;
        this.updateSendButtonState();
    }

    applyMessageText(value) {
        this.textMessage = value;

        if(this.textMessage.includes('{!')) {
            this.textMessage = this.textMessage.replace(/{!(.*?)}/g, (match, fieldName) => {
                if(fieldName.includes('Case.')) {
                    fieldName = fieldName.replace('Case.', '');
                }

                return this.case[fieldName] || match;
            });
        }

        this.updateSendButtonState();
    }

    handleQuickTextFolderChange(event) {
        this.quickTextFolderValue = event.detail.value;
        this.quickTextValue = '';
        this.quickTextOptions = [];

        if (this.quickTextFolderValue != '') {
            this.quickTextOptions = this.quickTextsList.filter(quickText => quickText.Folder.DeveloperName == this.quickTextFolderValue).map(quickText => {
                return { label: quickText.Name, value: quickText.Message };
            });

            this.quickTextOptions.unshift({ label: 'Nenhum', value: '' });
        }
    }

    handleQuickTextChange(event) {
        this.quickTextValue = event.detail.value;
        this.applyMessageText(this.quickTextValue);
    }

    updateSendButtonState() {
        const hasPhoneNumber = !!this.phoneNumber?.trim();
        const hasMessage = !!this.textMessage?.trim();
        const hasRecipient = !!this.recipientValue;

        this.disableSendSms = !(hasPhoneNumber && hasMessage && hasRecipient);
    }

    sendSMS() {
        this.disableSendSms = true;

        sendSMSMessage({ phoneNumber: this.phoneNumber, textMessage: this.textMessage, recordCase: this.case, recipientType: this.recipientValue })
        .then((result) => {
            if(result) {
                this.showNotification('Éxito', 'El SMS ha sido enviado.', 'success');
            } else {
                this.showNotification('Error', 'Ocurrió un error al enviar el SMS.', 'error');
            }

            this.closeAction();
        })
        .catch(error => {
            this.showNotification('Error', 'Ocurrió un error al enviar el SMS.', 'error');
            console.log('Error: ', error.body?.message || error.message);
            this.closeAction();
        });
    }

    showNotification(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}