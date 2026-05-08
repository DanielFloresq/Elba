/**
 * @description New Invoice component controller.
 *              Placed on the Order record page as a Quick Action.
 *              Shows services for the order (excluding guilds already invoiced)
 *              and creates one Invoice__c record with the selected services' guilds.
 * @author      Daniel Flores
 * @group       Invoice
 * @last modified on  : 29-04-2026
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent }   from 'lightning/platformShowToastEvent';
import { NavigationMixin }  from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
// Apex
import getOrderData         from '@salesforce/apex/NewInvoiceController.getOrderData';
import getServicesForOrder  from '@salesforce/apex/NewInvoiceController.getServicesForOrder';
import createInvoice        from '@salesforce/apex/NewInvoiceController.createInvoice';

// Custom Labels
import label_title               from '@salesforce/label/c.newInvoice_title';
import label_relatedOrder        from '@salesforce/label/c.newInvoice_relatedOrder';
import label_account             from '@salesforce/label/c.newInvoice_account';
import label_instructions        from '@salesforce/label/c.newInvoice_instructions';
import label_errorSelectService  from '@salesforce/label/c.newInvoice_errorSelectService';
import label_colName             from '@salesforce/label/c.newInvoice_colName';
import label_colType             from '@salesforce/label/c.newInvoice_colType';
import label_colStakeholder      from '@salesforce/label/c.newInvoice_colStakeholder';
import label_colBaseAmount       from '@salesforce/label/c.newInvoice_colBaseAmount';
import label_colVATAmount        from '@salesforce/label/c.newInvoice_colVATAmount';
import label_colTotalAmount      from '@salesforce/label/c.newInvoice_colTotalAmount';
import label_save                from '@salesforce/label/c.newInvoice_save';
import label_cancel              from '@salesforce/label/c.newInvoice_cancel';
import label_success             from '@salesforce/label/c.newInvoice_success';
import label_noServices          from '@salesforce/label/c.newInvoice_noServices';
import label_selectAll           from '@salesforce/label/c.newInvoice_selectAll';
import label_headerOrderNumber   from '@salesforce/label/c.newInvoice_headerOrderNumber';
import label_headerGuild         from '@salesforce/label/c.newInvoice_headerGuild';
import label_headerProviderType  from '@salesforce/label/c.newInvoice_headerProviderType';
import label_headerType          from '@salesforce/label/c.newInvoice_headerType';
import label_error               from '@salesforce/label/c.newInvoice_error';

export default class NewInvoice extends NavigationMixin(LightningElement) {

    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this._loadData();
        }
    }

    // â”€â”€ State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @track isLoading      = false;
    @track services       = [];

    orderName         = '';
    accountName       = '';
    orderGuild        = '';
    orderProviderType = '';
    orderType         = '';
    caseId            = null;

    showServiceError = false;

    // â”€â”€ Labels â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    labels = {
        title              : label_title,
        relatedOrder       : label_relatedOrder,
        account            : label_account,
        instructions       : label_instructions,
        errorSelectService : label_errorSelectService,
        colName            : label_colName,
        colType            : label_colType,
        colStakeholder     : label_colStakeholder,
        colBaseAmount      : label_colBaseAmount,
        colVATAmount       : label_colVATAmount,
        colTotalAmount     : label_colTotalAmount,
        save               : label_save,
        cancel             : label_cancel,
        success            : label_success,
        noServices         : label_noServices,
        selectAll          : label_selectAll,
        headerOrderNumber  : label_headerOrderNumber,
        headerGuild        : label_headerGuild,
        headerProviderType : label_headerProviderType,
        headerType         : label_headerType,
        error              : label_error
    };

    // â”€â”€ Lifecycle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    connectedCallback() {
        this.showServiceError = false;
    }

    async _loadData() {
        this.isLoading = true;
        try {
            const [orderData, services] = await Promise.all([
                getOrderData({ orderId: this._recordId }),
                getServicesForOrder({ orderId: this._recordId })
            ]);
            this.orderName         = orderData.orderName   || '';
            this.accountName       = orderData.accountName || '';
            this.caseId            = orderData.caseId      || null;
            this.orderGuild        = orderData.guild        || '\u2014';
            this.orderProviderType = orderData.providerType || '\u2014';
            this.orderType         = orderData.orderType    || '\u2014';
            this.services          = services.map(svc => ({ ...svc, selected: false }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title  : this.labels.error,
                message: error?.body?.message || error?.message || 'Unknown error.',
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    // â”€â”€ Getters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    get hasServices() {
        return this.services && this.services.length > 0;
    }

    get allSelected() {
        return this.hasServices && this.services.every(svc => svc.selected);
    }

    // â”€â”€ Handlers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleRowSelect(evt) {
        const svcId   = evt.target.dataset.id;
        this.services = this.services.map(svc =>
            svc.id === svcId ? { ...svc, selected: evt.target.checked } : svc
        );
        this.showServiceError = false;
    }

    handleSelectAll(evt) {
        const checked = evt.target.checked;
        this.services = this.services.map(svc => ({ ...svc, selected: checked }));
        if (checked) this.showServiceError = false;
    }

    async handleSave() {
        const selectedIds = this.services
            .filter(svc => svc.selected)
            .map(svc => svc.id);

        if (selectedIds.length === 0) {
            this.showServiceError = true;
            return;
        }

        this.isLoading = true;
        try {
            const createdId = await createInvoice({
                orderId    : this._recordId,
                serviceIds : selectedIds,
                caseId     : this.caseId
            });

            this.dispatchEvent(new ShowToastEvent({
                title  : this.labels.title,
                message: this.labels.success,
                variant: 'success'
            }));

            // Navigate to created Invoice record
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId  : createdId,
                    actionName: 'view'
                }
            });

            this.closeModal();
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title  : this.labels.error,
                message: error?.body?.message || error?.message || 'Unknown error.',
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }
}