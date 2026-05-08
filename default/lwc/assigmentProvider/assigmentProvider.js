/**
 * @description       :
 * @author            : Afonso Duque
 * @group             :
 * @last modified on  : 10-02-2026
 * @last modified by  : Afonso Duque
**/
import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { getObjectInfo, getPicklistValues  } from 'lightning/uiObjectInfoApi';
import { FlowNavigationNextEvent, FlowNavigationBackEvent, FlowNavigationFinishEvent } from 'lightning/flowSupport';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getProviders from '@salesforce/apex/ProviderAssignmentEngine.getAssignments';
import getAllDependentProviderGuilds from '@salesforce/apex/ProviderAssignmentEngine.getAllDependentProviderGuilds';
import createOrder from '@salesforce/apex/ProviderAssignmentEngine.createOrder';
import createAlgorithmOutcome from '@salesforce/apex/ProviderAssignmentEngine.createAlgorithmOutcome';

import CASENUMBER_FIELD from '@salesforce/schema/Order.CaseNumber__c';
import ORDER_OBJECT from '@salesforce/schema/Order';
import TYPE_FIELD from '@salesforce/schema/Order.Type';
import PROVIDER_TYPE_FIELD from '@salesforce/schema/Order.ProviderType__c';
import GUILD_FIELD from '@salesforce/schema/Order.Guild__c';

import PREVIOUS_BUTTON_LABEL from '@salesforce/label/c.PreviousButtonLabel';
import NEXT_BUTTON_LABEL from '@salesforce/label/c.NextButtonLabel';
import FINISH_BUTTON_LABEL from '@salesforce/label/c.FinishButtonLabel';
import ASSIGNMENT_TYPE_LABEL from '@salesforce/label/c.AssignTypeLabel';
import SELECT_PROVIDER_SCREEN_LABEL from '@salesforce/label/c.SelectScreenLabel';
import CONFIRMATION_SCREEN_LABEL from '@salesforce/label/c.ConfirmationScreenLabel';
import REASON_FIELD_LABEL from '@salesforce/label/c.ReasonFieldLabel';
import EMAIL_FIELD_LABEL from '@salesforce/label/c.EmailFieldLabel';
import PHONE_FIELD_LABEL from '@salesforce/label/c.PhoneFieldLabel';
import ADDRESS_FIELD_LABEL from '@salesforce/label/c.AddressFieldLabel';
import MANUAL_LABEL from '@salesforce/label/c.ManualLabel';
import AUTOMATIC_LABEL from '@salesforce/label/c.AutomaticLabel';
import NO_PROVIDERS_LABEL from '@salesforce/label/c.NoProvidersLabel';

export default class AssigmentProvider extends NavigationMixin(LightningElement) {

    @api
    objectType;
    @api
    recordId;
    @api
    selectedProviderId;
    @api
    isFirstScreen;
    @api
    isLastScreen;
    @api
    encargoId;

    @track
    providerList = [];
    @track
    selectedProvider;

    @track orderTypePicklistValues = [];
    @track providerTypePicklistValues = [];

    @track recordTypeId;

    providerTypeUrgent = [];
    providerTypeNotUrgent = [];
    guildsMapUrgent = new Map();
    guildsMapNotUrgent = new Map();

    providersTranslationMap = new Map();
    guildsTranslationMap = new Map();

    @track guildOptions = [];

    encargo = {
        id: undefined,
        type: '',
        providerType: '',
        guild: [],
        urgent: false,
        caseId: '',
        providerId: '',
        stepDescription: '',
        typeAssignment: '',
        description: ''
    };

    @wire(getObjectInfo, { objectApiName: ORDER_OBJECT })
    wiredOrderObjectInfo({ data, error }) {
        if (data) {
            const recordTypes = data.recordTypeInfos;
            const recordTypeInfo = Object.values(recordTypes)[0];
            if (recordTypeInfo) {
                this.recordTypeId = recordTypeInfo.recordTypeId;
            }

            // Store field labels
            const fields = data.fields;
            this.typeFieldLabel = fields.Type.label;
            this.providerTypeFieldLabel = fields.ProviderType__c.label;
            this.guildFieldLabel = fields.Guild__c.label;
            this.urgentFieldLabel = fields.Urgent__c.label;
            this.descriptionFieldLabel = fields.Description.label;
        } else if (error) {
            // Optionally handle error
            console.error('Error fetching Order object info: ' + error);
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: [CASENUMBER_FIELD] })
    orderRecord;

    get caseNumber() {
        return this.orderRecord.data ? this.orderRecord.data.fields.CaseNumber__c.value : '';
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: TYPE_FIELD })
    wiredOrderTypePicklistValues({ error, data }) {
        if (data) {
            this.orderTypePicklistValues = data.values.map(pv => ({
                label: pv.label,
                value: pv.value
            }));
        } else if (error) {
            console.error('Error retrieving order type picklist values: ', error);
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: PROVIDER_TYPE_FIELD })
    wiredProviderTypesTranslation({ error, data }) {
        if (data) {
            // Always re-initialize the map to avoid stale references
            this.providersTranslationMap = new Map();
            data.values.forEach(pv => {
                this.providersTranslationMap.set(pv.value, pv.label);
            });
        } else if (error) {
            console.error('Error retrieving provider type translation values: ', error);
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: GUILD_FIELD })
    wiredGuildsTranslation({ error, data }) {
        if (data) {
            data.values.forEach(pv => {
                this.guildsTranslationMap.set(pv.value, pv.label);
            });
        } else if (error) {
            console.error('Error retrieving guild translation values: ', error);
        }
    }

    previousButtonLabel = PREVIOUS_BUTTON_LABEL;
    nextButtonLabel = NEXT_BUTTON_LABEL
    finishButtonLabel = FINISH_BUTTON_LABEL;
    assignTypeLabel = ASSIGNMENT_TYPE_LABEL;
    selectProviderScreenLabel = SELECT_PROVIDER_SCREEN_LABEL
    confirmationScreenLabel = CONFIRMATION_SCREEN_LABEL;
    reasonFieldLabel = REASON_FIELD_LABEL
    emailFieldLabel = EMAIL_FIELD_LABEL
    phoneFieldLabel = PHONE_FIELD_LABEL
    noProvidersLabel = NO_PROVIDERS_LABEL;
    addressFieldLabel = ADDRESS_FIELD_LABEL;
    typeFieldLabel;
    providerTypeFieldLabel;
    guildFieldLabel;
    descriptionFieldLabel;

    assigmentValue = '';
    assignmentOptions = [
        { label: MANUAL_LABEL, value: 'Manual' },
        { label: AUTOMATIC_LABEL, value: 'Automatic' }
    ];

    get showPreviousButton() {
        return !this.isFirstScreen || (this.isFirstScreen && !this.typeAssignmentScreen && this.objectType == 'Order') || (this.isFirstScreen && !this.createOrderScreen && this.objectType == 'Case');
    }

    get showFinishButton() {
        return this.isLastScreen && this.confirmationScreen;
    }

    get showNextButton() {
        return !this.showFinishButton;
    }

    get hasProviders() {
        return this.providerList && this.providerList.length > 0;
    }

    isLoading = false;
    createOrderScreen = false;
    selectProviderGuildScreen = false;
    typeAssignmentScreen = false;
    selectProviderScreen = false;
    confirmationScreen = false;

    connectedCallback() {
        if(this.objectType === 'Case') {
            this.isLoading = true;
            getAllDependentProviderGuilds()
                .then((result) => {
                    setTimeout(() => {
                        this.createDependentProviderGuildsMaps(result);
                    }, 1000); // 1000ms delay to ensure maps are populated
                })
                .catch((error) => {
                    console.error('Error fetching dependent provider guilds: ' + error);
                }).finally(() => {
                    this.createOrderScreen = true;
                    this.encargo.caseId = this.recordId;
                    this.isLoading = false;
                });

        } else if(this.objectType === 'Order') {
            this.typeAssignmentScreen = true;
            setTimeout(() => {
                this.encargo.caseId = this.caseNumber;
                this.encargo.id = this.recordId;
                this.encargoId = this.recordId;
            }, 1000);
        }
    }

    createDependentProviderGuildsMaps(metaList) {
        metaList.forEach(metaValue => {
            if(metaValue.Urgency__c){
                this.setProviderTypeMaps(metaValue, this.providerTypeUrgent);
                this.setGuildMaps(metaValue, this.guildsMapUrgent);
            }
            this.setProviderTypeMaps(metaValue, this.providerTypeNotUrgent);
            this.setGuildMaps(metaValue, this.guildsMapNotUrgent);
        });
        this.providerTypePicklistValues = (this.encargo.urgent ? this.providerTypeUrgent : this.providerTypeNotUrgent) || [];
    }

    setProviderTypeMaps(provider, providerTypeMap) {
        const existingProviderType = providerTypeMap.find(pt => pt.value === provider.ProviderType__c);
        if(!existingProviderType) {
            providerTypeMap.push({
                label: this.providersTranslationMap.get(provider.ProviderType__c) || provider.ProviderType__c,
                value: provider.ProviderType__c
            });
        }
    }

    setGuildMaps(guildValue, guildsMap) {
        if(!guildsMap.has(guildValue.ProviderType__c)) {
            guildsMap.set(guildValue.ProviderType__c, [{
                label: this.guildsTranslationMap.get(guildValue.Guild__c) || guildValue.Guild__c,
                value: guildValue.Guild__c
            }]);
        } else {
            const existingGuilds = guildsMap.get(guildValue.ProviderType__c);
            existingGuilds.push({
                label: this.guildsTranslationMap.get(guildValue.Guild__c) || guildValue.Guild__c,
                value: guildValue.Guild__c
            });
            guildsMap.set(guildValue.ProviderType__c, existingGuilds);
        }
    }

    handleUrgentChange(event) {
        this.encargo.urgent = event.target.checked;
        this.encargo.providerType = '';
        this.guildOptions = [];
        this.encargo.guild = [];
        this.providerTypePicklistValues = (this.encargo.urgent ? this.providerTypeUrgent : this.providerTypeNotUrgent) || [];
        console.log('Urgency changed: ' + this.encargo.urgent + ', updated providerTypePicklistValues: ' + JSON.stringify(this.providerTypePicklistValues));
    }

    handleOrderTypeChange(event) {
        this.encargo.type = event.detail.value;
        console.log('Order Type changed: ' + this.encargo.type);
    }

    handleProviderTypeChange(event) {
        this.encargo.providerType = event.detail.value;
        this.encargo.guild = [];
        this.guildOptions = [];
        this.guildOptions = this.encargo.urgent ?
            (this.guildsMapUrgent.get(this.encargo.providerType) || []) :
            (this.guildsMapNotUrgent.get(this.encargo.providerType) || []);
        console.log('Provider Type changed: ' + this.encargo.providerType + ', updated guildOptions: ' + JSON.stringify(this.guildOptions));
    }

    handleGuildChange(event) {
        this.encargo.guild = event.detail.value;
        console.log('Guild changed: ' + this.encargo.guild);
    }

    onClickPrevious() {
        if(this.createOrderScreen){
            this.dispatchEvent(new FlowNavigationBackEvent());
        } else if(this.selectProviderGuildScreen){
            this.selectProviderGuildScreen = false;
            this.createOrderScreen = true;
        } else if(this.typeAssignmentScreen){
            if(this.objectType === 'Case') {
                this.typeAssignmentScreen = false;
                this.selectProviderGuildScreen = true;
            } else {
                this.dispatchEvent(new FlowNavigationBackEvent());
            }
        } else if(this.selectProviderScreen){
            this.unselectProvider();
            this.selectProviderScreen = false;
            this.typeAssignmentScreen = true;
        } else if(this.confirmationScreen){
            this.confirmationScreen = false;
            this.selectProviderScreen = true;
        }
    }

    onClickNext() {
        if (this.validateInput()) {
            if(this.createOrderScreen) {
                this.createOrderScreen = false;
                this.selectProviderGuildScreen = true;
            } else if(this.selectProviderGuildScreen) {
                this.isLoading = true;
                createOrder({orderInfoJSON: JSON.stringify(this.encargo), isAssignment: false})
                        .then((result) => {
                            this.encargoId = result;
                            this.encargo.id = result;
                            console.log('Encargo created with ID: ' + this.encargoId);
                            this.selectProviderGuildScreen = false;
                            this.typeAssignmentScreen = true;
                        })
                        .catch((error) => {
                            console.error('Error creating order: ' + error);
                            this.showToastEvent('Error', 'Ha ocurrido un error al crear el encargo.', 'error');
                        }).finally(() => {
                            this.isLoading = false;
                        });

            } else if(this.typeAssignmentScreen) {
                this.isLoading = true;
                getProviders({ encargoId: this.encargoId, isManual: (this.assigmentValue === 'Manual') })
                    .then(async (result) => {
                        try {
                            await createAlgorithmOutcome({
                                stepByStep: result.stepbyStepDescription != null ? result.stepbyStepDescription : '',
                                assignmentType: this.encargo.typeAssignment || this.assigmentValue,
                                recordId: this.encargoId
                            });
                        } catch (error) {
                            console.error('Error creating algorithm outcome: ' + error);
                        }
                        if(!result.success) {
                            this.showToastEvent('Error', 'Ha ocurrido un error al obtener los proveedores: ' + result.reason, 'error');
                        }
                        this.providerList = result.providers;
                        this.typeAssignmentScreen = false;
                        this.selectProviderScreen = true;
                    })
                    .catch((error) => {
                        console.error('Error fetching providers: ' + error);
                        this.showToastEvent('Error', 'Ha ocurrido un error al obtener los proveedores.', 'error');
                    }).finally(() => {
                        this.isLoading = false;
                    });
            } else if(this.selectProviderScreen && this.hasProviders) {
                this.isLoading = true;
                setTimeout(() => {
                    this.selectedProvider = this.providerList.find(provider => provider.id === this.selectedProviderId);
                    this.selectProviderScreen = false;
                    this.confirmationScreen = true;
                    this.isLoading = false;
                }, 500); // 500ms delay
            } else {
                let toastMessage = ((this.objectType === 'Case') ? 'Encargo creada con éxito! ' : 'Asignación realizada con éxito! ') + (this.selectedProvider ? ('Proveedor asignado: ' + this.selectedProvider.name) : '');
                if(this.hasProviders && this.encargo.providerId) {
                    this.isLoading = true;
                    createOrder({orderInfoJSON: JSON.stringify(this.encargo), isAssignment: true})
                            .then((result) => {
                                this.encargoId = result;
                                this.encargo.id = result;
                                console.log('Encargo created with ID: ' + this.encargoId);
                                this.dispatchEvent(new FlowNavigationFinishEvent());
                                this.navigateToRecord(this.encargoId);
                                this.showToastEvent('Success', toastMessage, 'success');
                            })
                            .catch((error) => {
                                console.error('Error creating order: ' + error);
                                this.showToastEvent('Error', 'Ha ocurrido un error al crear el encargo.', 'error');
                            }).finally(() => {
                                this.isLoading = false;
                            });
                } else {
                    this.dispatchEvent(new FlowNavigationFinishEvent());
                    this.navigateToRecord(this.encargoId);
                    this.showToastEvent('Success', toastMessage, 'success');
                }
            }
        }
    }

    onClickFinish() {
        this.dispatchEvent(new FlowNavigationFinishEvent());
    }

    selectProvider(event) {
        const currentChecked = event.target.dataset.checked === 'true';
        const checked = !currentChecked;
        if(checked) {
            this.selectedProviderId = checked ? event.target.dataset.id : null;
            this.selectedProvider = checked ? this.providerList.find(provider => provider.id === this.selectedProviderId) : null;
            this.providerList = this.providerList.map(provider => ({
                ...provider,
                isSelected: provider.id === this.selectedProviderId ? checked : false
            }));

            this.encargo.providerId = this.selectedProviderId;
            console.log('description: ' + this.selectedProvider.description);
            this.encargo.stepDescription = this.selectedProvider ? this.selectedProvider.description : '';
        } else {
            this.unselectProvider();
        }
    }

    unselectProvider() {
        this.selectedProvider = null;
        this.selectedProviderId = null;
        if(this.providerList) {
            this.providerList = this.providerList.map(provider => ({
                ...provider,
                isSelected: false
            }));
        }
        this.encargo.providerId = '';
        this.encargo.stepDescription = '';
    }

    handleTypeChange(event) {
        this.assigmentValue = event.detail.value;
        this.encargo.typeAssignment = this.assigmentValue;
    }

    handleDescriptionChange(event) {
        this.encargo.description = event.target.value;
    }

    validateInput() {
        if(this.createOrderScreen && (!this.encargo.type)) {
            this.showToastEvent('Error', 'Por favor seleccione un tipo de encargo.', 'error');
            return false;
        }
        if(this.selectProviderGuildScreen && (!this.encargo.providerType || this.encargo.guild.length === 0 || this.encargo.description.trim() === '')) {
            this.showToastEvent('Error', 'Por favor rellene los campos obligatorios.', 'error');
            return false;
        }
        if (this.typeAssignmentScreen && !this.assigmentValue) {
            this.showToastEvent('Error', 'Por favor seleccione un tipo de asignación.', 'error');
            return false;
        }
        if(this.selectProviderScreen && !this.selectedProviderId && this.hasProviders) {
            this.showToastEvent('Error', 'Por favor seleccione un proveedor.', 'error');
            return false;
        }
        return true;
    }

    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    showToastEvent(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
}