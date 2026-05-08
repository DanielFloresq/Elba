/**
 * @description New Credit Note component controller.
 *              Placed on the Order record page. Opens a modal to create
 *              Credit Note invoices linked to existing order invoices.
 * @author      Daniel Flores
 * @group       Invoice
 * @last modified on  : 28-04-2026
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';

// Apex
import getOrderData              from '@salesforce/apex/NewCreditNoteController.getOrderData';
import getAvailableInvoices      from '@salesforce/apex/NewCreditNoteController.getAvailableInvoices';
import getRectificationReasonOptions from '@salesforce/apex/NewCreditNoteController.getRectificationReasonOptions';
import createCreditNotes         from '@salesforce/apex/NewCreditNoteController.createCreditNotes';

// Custom Labels2
import label_title               from '@salesforce/label/c.newCreditNote_title';
import label_button              from '@salesforce/label/c.newCreditNote_button';
import label_relatedOrder        from '@salesforce/label/c.newCreditNote_relatedOrder';
import label_account             from '@salesforce/label/c.newCreditNote_account';
import label_rectificationReason from '@salesforce/label/c.newCreditNote_rectificationReason';
import label_selectInvoice       from '@salesforce/label/c.newCreditNote_selectInvoice';
import label_colInvoice          from '@salesforce/label/c.newCreditNote_colInvoice';
import label_colDate             from '@salesforce/label/c.newCreditNote_colDate';
import label_colAmount           from '@salesforce/label/c.newCreditNote_colAmount';
import label_save                from '@salesforce/label/c.newCreditNote_save';
import label_cancel              from '@salesforce/label/c.newCreditNote_cancel';
import label_selectOption        from '@salesforce/label/c.newCreditNote_selectOption';
import label_success             from '@salesforce/label/c.newCreditNote_success';
import label_errorRequired       from '@salesforce/label/c.newCreditNote_errorRequired';
import label_errorSelectInvoice  from '@salesforce/label/c.newCreditNote_errorSelectInvoice';
import label_noInvoices          from '@salesforce/label/c.newCreditNote_noInvoices';
import label_order               from '@salesforce/label/c.newCreditNote_order';

export default class NewCreditNote extends NavigationMixin(LightningElement) {

    // ── Public API ─────────────────────────────────────────────────────────
    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.openModal();
            this._loadData();
        }
    }

    // ── Lifecycle ──────────────────────────────────────────────────────────────

    connectedCallback() {}

    async _loadData() {
        this.isLoading = true;
        try {
            const [orderData, invoices, reasons] = await Promise.all([
                getOrderData({ orderId: this.recordId }),
                getAvailableInvoices({ orderId: this.recordId }),
                getRectificationReasonOptions()
            ]);
            this.orderName    = orderData.orderName;
            this.accountName  = orderData.accountName;
            this.caseId       = orderData.caseId || null;
            this.invoices     = invoices.map(inv => ({ ...inv, selected: false }));
            this.reasonOptions = reasons.map(opt => ({ label: opt.label, value: opt.value }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title  : 'Error',
                message: error?.body?.message || error?.message || 'Unknown error.',
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    // ── State ──────────────────────────────────────────────────────────────

    @track isLoading     = false;
    @track invoices      = [];
    @track reasonOptions = [];

    orderName     = '';
    accountName   = '';
    caseId        = null;
    selectedReason = '';

    showReasonError  = false;
    showInvoiceError = false;

    // ── Labels ─────────────────────────────────────────────────────────────

    labels = {
        title               : label_title,
        button              : label_button,
        relatedOrder        : label_relatedOrder,
        account             : label_account,
        rectificationReason : label_rectificationReason,
        selectInvoice       : label_selectInvoice,
        colInvoice          : label_colInvoice,
        colDate             : label_colDate,
        colAmount           : label_colAmount,
        save                : label_save,
        cancel              : label_cancel,
        selectOption        : label_selectOption,
        success             : label_success,
        errorRequired       : label_errorRequired,
        errorSelectInvoice  : label_errorSelectInvoice,
        noInvoices          : label_noInvoices,
        order               : label_order
    };

    // ── Getters ────────────────────────────────────────────────────────────

    get hasInvoices() {
        return this.invoices && this.invoices.length > 0;
    }

    get allSelected() {
        return this.hasInvoices && this.invoices.every(inv => inv.selected);
    }

    get reasonClass() {
        return this.showReasonError ? 'slds-has-error' : '';
    }

    // ── Handlers ───────────────────────────────────────────────────────────

    openModal() {
        // Reset state
        this.selectedReason   = '';
        this.showReasonError  = false;
        this.showInvoiceError = false;
        this.invoices = (this.invoices || []).map(inv => ({ ...inv, selected: false }));
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleReasonChange(evt) {
        this.selectedReason  = evt.detail.value;
        this.showReasonError = false;
    }

    handleRowSelect(evt) {
        const invoiceId = evt.target.dataset.id;
        this.invoices = this.invoices.map(inv =>
            inv.id === invoiceId ? { ...inv, selected: evt.target.checked } : inv
        );
        this.showInvoiceError = false;
    }

    handleSelectAll(evt) {
        const checked = evt.target.checked;
        this.invoices = this.invoices.map(inv => ({ ...inv, selected: checked }));
        if (checked) this.showInvoiceError = false;
    }

    navigateToInvoice(evt) {
        const invoiceId = evt.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId  : invoiceId,
                actionName: 'view'
            }
        });
    }

    async handleSave() {
        // Validate
        let valid = true;

        if (!this.selectedReason) {
            this.showReasonError = true;
            valid = false;
        }

        const selectedIds = this.invoices
            .filter(inv => inv.selected)
            .map(inv => inv.id);

        if (selectedIds.length === 0) {
            this.showInvoiceError = true;
            valid = false;
        }

        if (!valid) return;

        this.isLoading = true;
        try {
            const createdIds = await createCreditNotes({
                orderId             : this.recordId,
                rectificationReason : this.selectedReason,
                relatedInvoiceIds   : selectedIds,
                caseId              : this.caseId
            });

            this.dispatchEvent(new ShowToastEvent({
                title  : this.labels.title,
                message: this.labels.success,
                variant: 'success'
            }));

            // Navigate to the first created credit note
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId  : createdIds[0],
                    actionName: 'view'
                }
            });

            this.closeModal();
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title  : 'Error',
                message: error?.body?.message || error?.message || 'Unknown error',
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }
}