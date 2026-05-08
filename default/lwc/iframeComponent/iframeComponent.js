import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

const FIELDS = ['Order.iFrame__c'];

export default class IframeComponent extends LightningElement {
    @api recordId;

    iframeUrl;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredOrder({ error, data }) {
        if (data) {
        this.iframeUrl = data.fields.iFrame__c.value;
        } else if (error) {
        console.error('Error searching the iframe:', error);
        }
    }
}