/**
 * @description       : LWC component for Flow usage, allowing selection of available Guilds with advanced filtering based on related Accounts and related Services (no dependency on Order). Supports single (combobox) or multiple (dual list box) selection and exposes the selected values as an array of API names for Flow.
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 05-05-2026
 * @last modified by  : Daniel Flores
**/
import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import getAvailableGuildOptions from '@salesforce/apex/GuildFlowSelectorController.getAvailableGuildOptions';

export default class GuildFlowSelector extends LightningElement {
    @api label = 'Guild';
    @api required = false;
    @api selectionMode = 'single';
    @api emptyMessage = 'Sem guilds disponíveis para seleção.';

    @api selectedValue;
    @api stakeHolderSelected;
    @api selectedValues;
    @api selectedApiValues = [];

    options = [];
    loadError;
    hasConnected = false;
    _guildValues;
    _orderId;
    _providerId;
    _relatedAccountIds;
    _relatedServiceIds;
    lastRequestKey;

    // Deprecated input kept for Flow backwards-compatibility.
    // This component no longer reads Order.
    @api
    get orderId() {
        return this._orderId;
    }

    set orderId(value) {
        this._orderId = value;
    }

    @api
    get guildValues() {
        return this._guildValues;
    }

    set guildValues(value) {
        this._guildValues = value;
        this.loadOptions();
    }

    @api
    get providerId() {
        return this._providerId;
    }

    
    set providerId(value) {
        this._providerId = value;
        this.loadOptions();
    }

    @api
    get relatedAccountIds() {
        return this._relatedAccountIds;
    }

    set relatedAccountIds(value) {
        this._relatedAccountIds = value;
        this.loadOptions();
    }

    @api
    get relatedServiceIds() {
        return this._relatedServiceIds;
    }

    set relatedServiceIds(value) {
        this._relatedServiceIds = value;
        this.loadOptions();
    }

    connectedCallback() {
        this.hasConnected = true;
        this.loadOptions();
    }

    get isSingleSelect() {
        return this.selectionMode !== 'multiple';
    }

    get hasOptions() {
        return this.options && this.options.length > 0;
    }

    get displayMessage() {
        return this.loadError || this.emptyMessage;
    }

    get selectedValuesArray() {
        if (!this.selectedValues) {
            return [];
        }

        return this.selectedValues
            .split(';')
            .map((value) => value && value.trim())
            .filter((value) => Boolean(value));
    }

    handleSingleChange(event) {
        this.selectedValue = event.detail.value;
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedValue', this.selectedValue));
        this.selectedApiValues = this.selectedValue ? [this.selectedValue] : [];
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedApiValues', this.selectedApiValues));
    }

    handleMultiChange(event) {
        const values = event.detail.value || [];
        this.selectedValues = values.join(';');
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedValues', this.selectedValues));
        this.selectedApiValues = [...values];
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedApiValues', this.selectedApiValues));
    }

    async loadOptions() {
        if (!this.hasConnected) {
            return;
        }

        const normalizedGuildValues = this.normalizeGuildValues(this.guildValues);
        const normalizedAccountIds = this.normalizeIdList(this.relatedAccountIds);
        const normalizedServiceIds = this.normalizeIdList(this.relatedServiceIds);

        if (!normalizedGuildValues && (!normalizedAccountIds || !normalizedAccountIds.length)) {
            this.options = [];
            this.loadError = null;
            this.syncDefaultOutputs();
            return;
        }

        const requestKey = JSON.stringify({
            providerId: this.providerId || null,
            guildValues: normalizedGuildValues,
            relatedAccountIds: normalizedAccountIds,
            relatedServiceIds: normalizedServiceIds
        });
        this.lastRequestKey = requestKey;

        try {
            const response = await getAvailableGuildOptions({
                providerId: this.providerId || null,
                guildValues: normalizedGuildValues,
                relatedAccountIds: normalizedAccountIds,
                relatedServiceIds: normalizedServiceIds,
                stakeHolderSelected: this.stakeHolderSelected || null
            });

            if (this.lastRequestKey !== requestKey) {
                return;
            }

            this.options = (response || []).map((item) => ({
                label: item.label,
                value: item.value
            }));
            this.loadError = null;
            this.syncDefaultOutputs();
        } catch (error) {
            if (this.lastRequestKey !== requestKey) {
                return;
            }

            this.options = [];
            this.loadError = this.resolveErrorMessage(error);
            this.syncDefaultOutputs();
        }
    }

    syncDefaultOutputs() {
        if (!this.hasOptions) {
            if (this.selectedValue) {
                this.selectedValue = null;
                this.dispatchEvent(new FlowAttributeChangeEvent('selectedValue', this.selectedValue));
            }

            if (this.selectedValues) {
                this.selectedValues = '';
                this.dispatchEvent(new FlowAttributeChangeEvent('selectedValues', this.selectedValues));
            }

            if (this.selectedApiValues.length) {
                this.selectedApiValues = [];
                this.dispatchEvent(new FlowAttributeChangeEvent('selectedApiValues', this.selectedApiValues));
            }
            return;
        }

        const validValues = new Set(this.options.map((option) => option.value));

        if (this.isSingleSelect) {
            if (!this.selectedValue || !validValues.has(this.selectedValue)) {
                this.selectedValue = this.options[0].value;
                this.dispatchEvent(new FlowAttributeChangeEvent('selectedValue', this.selectedValue));
            }
            this.selectedApiValues = this.selectedValue ? [this.selectedValue] : [];
            this.dispatchEvent(new FlowAttributeChangeEvent('selectedApiValues', this.selectedApiValues));
            return;
        }

        const normalizedSelectedValues = this.selectedValuesArray.filter((value) => validValues.has(value));
        const joinedSelectedValues = normalizedSelectedValues.join(';');
        if (this.selectedValues !== joinedSelectedValues) {
            this.selectedValues = joinedSelectedValues;
            this.dispatchEvent(new FlowAttributeChangeEvent('selectedValues', this.selectedValues));
        }
        this.selectedApiValues = normalizedSelectedValues;
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedApiValues', this.selectedApiValues));
    }

    normalizeGuildValues(rawGuildValues) {
        if (rawGuildValues === null || rawGuildValues === undefined) {
            return '';
        }

        if (typeof rawGuildValues === 'string') {
            return rawGuildValues;
        }

        if (Array.isArray(rawGuildValues)) {
            return rawGuildValues
                .map((value) => value === null || value === undefined ? '' : String(value))
                .join(';');
        }

        return String(rawGuildValues);
    }

    normalizeIdList(rawIds) {
        if (rawIds === null || rawIds === undefined) {
            return [];
        }

        if (Array.isArray(rawIds)) {
            return rawIds
                .map((value) => value && String(value).trim())
                .filter((value) => Boolean(value));
        }

        if (typeof rawIds === 'string') {
            return rawIds
                .split(';')
                .map((value) => value && value.trim())
                .filter((value) => Boolean(value));
        }

        return [String(rawIds).trim()].filter((value) => Boolean(value));
    }

    resolveErrorMessage(error) {
        if (error && error.body) {
            if (Array.isArray(error.body)) {
                return error.body.map((item) => item.message).join(', ');
            }
            if (error.body.message) {
                return error.body.message;
            }
        }

        return 'Erro ao carregar guilds disponíveis.';
    }
}