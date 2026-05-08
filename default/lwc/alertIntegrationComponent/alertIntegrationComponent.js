import { LightningElement, api } from 'lwc';
import { subscribe, unsubscribe } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';
import { NavigationMixin } from 'lightning/navigation';

export default class PopUpServiceComponent extends NavigationMixin(LightningElement) {
    @api recordId; // ID do registo atual
    channelName = '/event/PopUP_Service__e';
    subscription = {};

    connectedCallback() {
        this.handleSubscribe();
    }

    handleSubscribe() {
        const messageCallback = (response) => {
            console.log('New message received: ', JSON.stringify(response));

            const payload = response.data.payload;
            const message = payload.Message__c;
            const success = payload.Success__c;
            const recordId = payload.RecordId__c;

            console.log('PAYLOAD SUCCESS:', success);
            console.log('RECORD ID:', recordId);
            console.log('CURRENT RECORD ID:', this.recordId);

            // Só executa refresh se for um create de MKIS
            // Supondo que a mensagem de create contém a palavra 'criado' ou 'create' (ajuste conforme padrão real)
            const isCreate = message && (message.toLowerCase().includes('criado') || message.toLowerCase().includes('create'));

            if (recordId === this.recordId) {
                if (success === true) {
                    this.showToast('Success', message, 'success');
                    if (isCreate) {
                        this.refreshPage();
                    }
                } else if (success === false) {
                    this.showToast('Error', message, 'error');
                }
            } else {
                console.log('Evento ignorado: RecordId diferente.');
            }
        };

        subscribe(this.channelName, -1, messageCallback).then(response => {
            this.subscription = response;
            console.log('Subscribed to channel: ', response.channel);
        });
    }

    handleUnsubscribe() {
        unsubscribe(this.subscription, response => {
            console.log('Unsubscribed: ', response);
        });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }

    refreshPage() {
        this.dispatchEvent(new RefreshEvent());
    }
}