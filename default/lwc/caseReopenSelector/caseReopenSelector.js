/**
 * @description       : LWC controller for the Case Reopen Selector component.
 *                      - On a Case page: shows reopening reason picklist, related
 *                        Orders with child Services in an accordion, and allows
 *                        multi-select with validation.
 *                      - On an Order page: shows only the Services datatable.
 * @author            : Daniel Flores
 * @last modified on  : 20-04-2026
 * @last modified by  : Daniel Flores
 */
import { LightningElement, api, wire, track } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';

// Apex methods
import getReopeningReasons from '@salesforce/apex/CaseReopenSelectorController.getReopeningReasons';
import getOrdersWithServices from '@salesforce/apex/CaseReopenSelectorController.getOrdersWithServices';
import getServicesForOrder from '@salesforce/apex/CaseReopenSelectorController.getServicesForOrder';
import reopenOrderAndServices from '@salesforce/apex/CaseReopenSelectorController.reopenOrderAndServices';
import saveReopeningSelection from '@salesforce/apex/CaseReopenSelectorController.saveReopeningSelection';
import submitClaimReopeningApproval from '@salesforce/apex/CaseReopenSelectorController.submitClaimReopeningApproval';

// Object tokens for context detection
import CASE_OBJECT from '@salesforce/schema/Case';
import ORDER_OBJECT from '@salesforce/schema/Order';

// ─── Column definitions ─────────────────────────────────────────────
const SERVICE_COLUMNS_CASE = [
    { label: 'Nombre', fieldName: 'name', type: 'text' },
    { label: 'Type', fieldName: 'typeName', type: 'text' },
    { label: 'Stakeholder', fieldName: 'stakeholderName', type: 'text' }
];

const SERVICE_COLUMNS_ORDER = [
    { label: 'Nombre', fieldName: 'name', type: 'text' },
    { label: 'Type', fieldName: 'typeName', type: 'text' },
    { label: 'Stakeholder', fieldName: 'stakeholderName', type: 'text' }
];

export default class CaseReopenSelector extends LightningElement {

    // ─── Public API ──────────────────────────────────────────────────
    _recordId;
    _objectApiName;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        this._tryInitialize();
    }

    @api
    get objectApiName() {
        return this._objectApiName;
    }

    set objectApiName(value) {
        this._objectApiName = value;
        this._tryInitialize();
    }

    // ─── Reactive state ──────────────────────────────────────────────

    // Picklist
    reopeningOptions = [];
    selectedReason = '';
    reopeningDescription = '';

    // Orders + Services (Case page)
    @track ordersViewModel = []; // enriched view-model array
    isLoadingOrders = false;
    isSavingSelection = false;
    isSubmittingApproval = false;
    ordersError = '';
    validationError = '';

    // Services only (Order page)
    @track orderServiceRows = [];
    @track selectedOrderPageServiceIds = [];
    isLoadingOrderServices = false;
    orderServicesError = '';

    // Internal maps
    _rawOrdersData = [];          // raw Apex response
    _selectedOrderIds = new Set();
    _selectedServiceIdsByOrder = {}; // { orderId: Set<serviceId> }
    _initializedContextKey;
    caseKeyPrefix;
    orderKeyPrefix;

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    wiredCaseObjectInfo({ data }) {
        if (data) {
            this.caseKeyPrefix = data.keyPrefix;
            this._tryInitialize();
        }
    }

    @wire(getObjectInfo, { objectApiName: ORDER_OBJECT })
    wiredOrderObjectInfo({ data }) {
        if (data) {
            this.orderKeyPrefix = data.keyPrefix;
            this._tryInitialize();
        }
    }

    // ─── Computed getters ────────────────────────────────────────────

    get resolvedObjectApiName() {
        if (this.objectApiName) {
            return this.objectApiName;
        }

        if (this.recordId && this.caseKeyPrefix && this.recordId.startsWith(this.caseKeyPrefix)) {
            return 'Case';
        }

        if (this.recordId && this.orderKeyPrefix && this.recordId.startsWith(this.orderKeyPrefix)) {
            return 'Order';
        }

        return null;
    }

    /** True when component sits on a Case record page */
    get isCasePage() {
        return this.resolvedObjectApiName === 'Case';
    }

    /** True when component sits on an Order record page */
    get isOrderPage() {
        return this.resolvedObjectApiName === 'Order';
    }

    /** Show orders section only after a reason has been chosen */
    get showOrders() {
        return this.isCasePage && !!this.selectedReason;
    }

    get hasOrders() {
        return !this.isLoadingOrders && !this.ordersError && this.ordersViewModel.length > 0;
    }

    get hasNoOrders() {
        return !this.isLoadingOrders && !this.ordersError && this.ordersViewModel.length === 0 && this.showOrders;
    }

    get hasOrderServices() {
        return !this.isLoadingOrderServices && !this.orderServicesError && this.orderServiceRows.length > 0;
    }

    get hasNoOrderServices() {
        return !this.isLoadingOrderServices && !this.orderServicesError && this.orderServiceRows.length === 0;
    }

    get isBusy() {
        return this.isLoadingOrders || this.isSavingSelection || this.isSubmittingApproval;
    }

    /** Column definitions exposed to the template */
    get serviceColumns() {
        return SERVICE_COLUMNS_CASE;
    }

    get serviceColumnsOrderPage() {
        return SERVICE_COLUMNS_ORDER;
    }

    /** All Order Ids — used to open all accordion sections by default */
    get allOrderIds() {
        return this.ordersViewModel.map(o => o.orderId);
    }

    // ─── Lifecycle ───────────────────────────────────────────────────

    connectedCallback() {
        this._tryInitialize();
    }

    // ─── Picklist loading ────────────────────────────────────────────

    async _loadReopeningReasons() {
        try {
            const data = await getReopeningReasons();
            this.reopeningOptions = data.map(opt => ({
                label: opt.label,
                value: opt.value
            }));
        } catch (error) {
            this._showToast('Error', this._reduceError(error), 'error');
        }
    }

    // ─── Event handlers ──────────────────────────────────────────────

    /**
     * @description User selects a reopening reason → load Orders + Services.
     */
    handleReasonChange(event) {
        this.selectedReason = event.detail.value;
        this.validationError = '';
        this._loadOrdersWithServices();
    }

    handleDescriptionChange(event) {
        this.reopeningDescription = event.detail.value;
        this.validationError = '';
    }

    /**
     * @description Checkbox on an Order row toggled.
     */
    handleOrderCheckbox(event) {
        const orderId = event.target.dataset.orderId;
        const checked = event.target.checked;

        if (checked) {
            this._selectedOrderIds.add(orderId);
        } else {
            this._selectedOrderIds.delete(orderId);
            // Also clear service selections for this order
            delete this._selectedServiceIdsByOrder[orderId];
        }

        this._rebuildViewModel();
    }

    /**
     * @description Service row(s) selected inside a datatable.
     */
    handleServiceSelection(event) {
        const selectedRows = event.detail.selectedRows;
        const orderId = event.target.dataset.orderId;

        if (!orderId) return;

        const serviceIds = new Set(selectedRows.map(r => r.id));
        this._selectedServiceIdsByOrder[orderId] = serviceIds;

        // Auto-select the parent Order when a service is checked
        if (serviceIds.size > 0) {
            this._selectedOrderIds.add(orderId);
        }

        this._rebuildViewModel();
    }

    /**
     * @description User clicks "Confirmar selección".
     */
    async handleConfirm() {
        if (this.isOrderPage) {
            await this._handleOrderReopen();
            return;
        }

        this.validationError = '';

        // Build output
        const selectedOrders = this.selectedOrderIds;
        const selectedServices = this.selectedServiceIds;
        let hasValidationIssue = false;

        for (const orderId of selectedOrders) {
            const svcIds = this._selectedServiceIdsByOrder[orderId];
            if (!svcIds || svcIds.size === 0) {
                hasValidationIssue = true;
                break;
            }
            svcIds.forEach(id => selectedServices.push(id));
        }

        // Validation: at least one order must be selected
        if (selectedOrders.length === 0) {
            this.validationError = 'Debe seleccionar al menos un encargo (Order).';
            return;
        }

        if (!this.reopeningDescription || !this.reopeningDescription.trim()) {
            this.validationError = 'Debe rellenar la descripción de la reapertura.';
            return;
        }

        // Validation: every selected order must have at least one service
        if (hasValidationIssue) {
            this.validationError = 'Cada encargo seleccionado debe tener al menos un servicio seleccionado.';
            return;
        }

        // Build payload
        const payload = {
            reopeningReason: this.selectedReason,
            reopeningDescription: this.reopeningDescription,
            selectedOrders,
            selectedServices
        };

        try {
            this.isSavingSelection = true;
            await saveReopeningSelection({
                caseId: this.recordId,
                reopeningReason: this.selectedReason,
                reopeningDescription: this.reopeningDescription,
                selectedOrderIds: selectedOrders,
                selectedServiceIds: selectedServices,
                availableOrderIds: this.availableOrderIds,
                availableServiceIds: this.availableServiceIds
            });
        } catch (error) {
            this._showToast('Error', this._reduceError(error), 'error');
            return;
        } finally {
            this.isSavingSelection = false;
        }

        try {
            this.isSubmittingApproval = true;
            await submitClaimReopeningApproval({ caseId: this.recordId });
        } catch (error) {
            this._showToast('Error', this._reduceError(error), 'error');
            return;
        } finally {
            this.isSubmittingApproval = false;
        }

        // Fire custom event so parent components / Flow / Aura can consume it
        this.dispatchEvent(new CustomEvent('selectionconfirmed', {
            detail: payload,
            bubbles: true,
            composed: true
        }));

        this._showToast(
            'Éxito',
            'La solicitud de reapertura fue enviada a aprobación correctamente.',
            'success'
        );
        this._forceRefreshAndClose();

        // eslint-disable-next-line no-console
        console.log('[CaseReopenSelector] Output payload:', JSON.stringify(payload));
    }

    handleOrderPageServiceSelection(event) {
        this.validationError = '';
        this.selectedOrderPageServiceIds = event.detail.selectedRows.map(row => row.id);
    }

    // ─── Data loading (Case page) ────────────────────────────────────

    async _loadOrdersWithServices() {
        this.isLoadingOrders = true;
        this.ordersError = '';
        this.ordersViewModel = [];
        this._rawOrdersData = [];
        this._selectedOrderIds = new Set();
        this._selectedServiceIdsByOrder = {};

        try {
            const data = await getOrdersWithServices({ caseId: this.recordId });
            this._rawOrdersData = data || [];
            this._rebuildViewModel();
        } catch (error) {
            this.ordersError = this._reduceError(error);
        } finally {
            this.isLoadingOrders = false;
        }
    }

    // ─── Data loading (Order page) ───────────────────────────────────

    async _loadOrderServices() {
        this.isLoadingOrderServices = true;
        this.orderServicesError = '';
        this.orderServiceRows = [];

        try {
            const data = await getServicesForOrder({ orderId: this.recordId });
            this.orderServiceRows = (data || []).map(svc => this._mapServiceRow(svc));
            this.selectedOrderPageServiceIds = [];
        } catch (error) {
            this.orderServicesError = this._reduceError(error);
        } finally {
            this.isLoadingOrderServices = false;
        }
    }

    // ─── ViewModel builder ───────────────────────────────────────────

    /**
     * Rebuilds the @track ordersViewModel from raw data + selections.
     */
    _rebuildViewModel() {
        this.ordersViewModel = this._rawOrdersData.map(ow => {
            const orderId = ow.orderRecord.Id;
            const isSelected = this._selectedOrderIds.has(orderId);
            const selectedSvcIds = this._selectedServiceIdsByOrder[orderId]
                ? [...this._selectedServiceIdsByOrder[orderId]]
                : [];

            const services = (ow.services || []).map(svc => this._mapServiceRow(svc));

            return {
                orderId,
                orderNumber: ow.orderRecord.OrderNumber || '—',
                guild: ow.orderRecord.Guild__c || '—',
                providerType: ow.orderRecord.ProviderType__c || '—',
                orderType: ow.orderRecord.Type || '—',
                accordionLabel: `Encargo ${ow.orderRecord.OrderNumber || ''}`,
                isSelected,
                hasServices: services.length > 0,
                services,
                selectedServiceIds: selectedSvcIds
            };
        });
    }

    /**
     * Maps a raw Service__c record to a flat row for lightning-datatable.
     */
    _mapServiceRow(svc) {
        return {
            id: svc.Id,
            name: svc.Name || '—',
            typeName: svc.Type__c || '—',
            stakeholderName: svc.Stakeholder__r ? svc.Stakeholder__r.Name : '—'
        };
    }

    // ─── Utilities ───────────────────────────────────────────────────

    get selectedOrderIds() {
        return [...this._selectedOrderIds];
    }

    get selectedServiceIds() {
        const serviceIds = [];
        Object.values(this._selectedServiceIdsByOrder).forEach(ids => {
            if (ids) {
                ids.forEach(id => serviceIds.push(id));
            }
        });
        return serviceIds;
    }

    get availableOrderIds() {
        return this._rawOrdersData.map(ow => ow.orderRecord.Id);
    }

    get availableServiceIds() {
        return this._rawOrdersData.flatMap(ow => (ow.services || []).map(serviceRecord => serviceRecord.Id));
    }

    get availableOrderPageServiceIds() {
        return this.orderServiceRows.map(row => row.id);
    }

    async _handleOrderReopen() {
        this.validationError = '';

        if (this.selectedOrderPageServiceIds.length === 0) {
            this.validationError = 'Debe seleccionar al menos un servicio.';
            return;
        }

        try {
            this.isSavingSelection = true;
            await reopenOrderAndServices({
                orderId: this.recordId,
                selectedServiceIds: this.selectedOrderPageServiceIds,
                availableServiceIds: this.availableOrderPageServiceIds
            });
        } catch (error) {
            this._showToast('Error', this._reduceError(error), 'error');
            return;
        } finally {
            this.isSavingSelection = false;
        }

        this.dispatchEvent(new CustomEvent('selectionconfirmed', {
            detail: {
                selectedOrders: [this.recordId],
                selectedServices: [...this.selectedOrderPageServiceIds]
            },
            bubbles: true,
            composed: true
        }));

        this._showToast(
            'Éxito',
            'El encargo y los servicios seleccionados fueron reabiertos correctamente.',
            'success'
        );

        this._forceRefreshAndClose();
        
    }

    _tryInitialize() {
        if (!this.recordId || !this.resolvedObjectApiName) {
            return;
        }

        const contextKey = `${this.resolvedObjectApiName}:${this.recordId}`;
        if (this._initializedContextKey === contextKey) {
            return;
        }

        this._initializedContextKey = contextKey;

        if (this.isCasePage) {
            this._loadReopeningReasons();
            return;
        }

        if (this.isOrderPage) {
            this._loadOrderServices();
        }
    }

    /**
     * Reduces an error object to a readable string.
     */
    _reduceError(error) {
        if (typeof error === 'string') return error;
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        return 'Error desconocido.';
    }

    /**
     * Shows a platform toast notification.
     */
    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _forceRefreshAndClose() {
        this.dispatchEvent(new RefreshEvent());
        this.dispatchEvent(new CloseActionScreenEvent());

        if (typeof window === 'undefined') {
            return;
        }

        window.setTimeout(() => {
            try {
                window.location.reload();
            } catch (error) {
                window.location.assign(window.location.href);
            }
        }, 300);
    }
}