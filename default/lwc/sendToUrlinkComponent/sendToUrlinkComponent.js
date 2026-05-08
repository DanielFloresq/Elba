import { LightningElement, api } from 'lwc';
import createServiceFromButton from '@salesforce/apex/MKISElbaServiceHandler.createServiceFromButton';
import validateMandatoryFields from '@salesforce/apex/CreateNewServiceController.validateMandatoryFields';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';
import { getRecordNotifyChange, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import LANG from '@salesforce/i18n/lang';

export default class SendToUrlinkComponent extends LightningElement {
    @api recordId;

    fieldLabels = {
        providerTaxNumber: {
            pt: 'NIF do prestador',
            es: 'NIF del proveedor',
            en: 'Provider tax number'
        },
        providerEmail: {
            pt: 'Email do prestador',
            es: 'Email del proveedor',
            en: 'Provider email'
        },
        providerName: {
            pt: 'Nome do prestador',
            es: 'Nombre del proveedor',
            en: 'Provider name'
        },
        orderNumber: {
            pt: 'Número do encargo',
            es: 'Número del encargo',
            en: 'Order number'
        },
        caseNumber: {
            pt: 'Número do sinistro',
            es: 'Número del expediente',
            en: 'Case number'
        },
        policyNumber: {
            pt: 'Número da apólice',
            es: 'Número de póliza',
            en: 'Policy number'
        },
        insuranceCompany: {
            pt: 'Cliente / Seguradora',
            es: 'Cliente / Cía Seguros',
            en: 'Client / Insurance company'
        },
        insuredName: {
            pt: 'Nome do segurado',
            es: 'Nombre del asegurado',
            en: 'Insured name'
        },
        insuredIdentification: {
            pt: 'Documento de identificação do segurado',
            es: 'Documento de identificación del asegurado',
            en: 'Insured identification'
        },
        policyPhoneNumber: {
            pt: 'Telefone da apólice',
            es: 'Teléfono de póliza',
            en: 'Policy phone number'
        },
        address: {
            pt: 'Morada',
            es: 'Dirección',
            en: 'Address'
        },
        postalCode: {
            pt: 'Código postal',
            es: 'Código postal',
            en: 'Postal code'
        },
        city: {
            pt: 'Cidade',
            es: 'Ciudad',
            en: 'City'
        },
        district: {
            pt: 'Distrito',
            es: 'Provincia / distrito',
            en: 'District'
        },
        contactRelation: {
            pt: 'Relação com o segurado',
            es: 'Relación con el asegurado',
            en: 'Relationship to the insured'
        },
        contactPhoneNumber: {
            pt: 'Telemóvel de contacto',
            es: 'Móvil de contacto',
            en: 'Contact mobile phone'
        },
        contactEmailAddress: {
            pt: 'Email de contacto',
            es: 'Email de contacto',
            en: 'Contact email'
        },
        occurrenceDate: {
            pt: 'Data e hora do encargo',
            es: 'Fecha y hora del encargo',
            en: 'Service date and time'
        },
        description: {
            pt: 'Descrição do sinistro',
            es: 'Descripción del siniestro',
            en: 'Claim description'
        },
        assignedJob: {
            pt: 'Ofício atribuído',
            es: 'Oficio asignado',
            en: 'Assigned job'
        },
        operatorName: {
            pt: 'Nome do tramitador',
            es: 'Nombre del tramitador',
            en: 'Operator name'
        },
        operatorEmailAddress: {
            pt: 'Email do tramitador',
            es: 'Email del tramitador',
            en: 'Operator email'
        },
        productCode: {
            pt: 'Código do produto / ramo',
            es: 'Código de producto / ramo',
            en: 'Product code / line of business'
        },
        declarationDate: {
            pt: 'Data da declaração',
            es: 'Fecha de declaración',
            en: 'Declaration date'
        },
        policyEffectiveDate: {
            pt: 'Data de efeito da apólice',
            es: 'Fecha de efecto de la póliza',
            en: 'Policy effective date'
        },
        stakeholderName: {
            pt: 'Stakeholders - Nome',
            es: 'Implicado - Nombre',
            en: 'Stakeholders - Name'
        },
        stakeholderType: {
            pt: 'Stakeholders - Tipo',
            es: 'Implicado - Tipo',
            en: 'Stakeholders - Type'
        },
        stakeholderTaxNumber: {
            pt: 'Stakeholders - NIF',
            es: 'Implicado - NIF',
            en: 'Stakeholders - Tax number'
        },
        stakeholderPhoneNumber: {
            pt: 'Stakeholders - Telefone',
            es: 'Implicado - Teléfono',
            en: 'Stakeholders - Phone number'
        },
        stakeholderAddress: {
            pt: 'Stakeholders - Morada',
            es: 'Implicado - Dirección',
            en: 'Stakeholders - Address'
        }
    };

    messages = {
        pt: {
            validationTitle: 'Campos obrigatórios em falta',
            validationSummary: 'Existem {0} campos obrigatórios por preencher antes de enviar para Urlink.',
            validationFieldsLabel: 'Campos em falta: {0}',
            successTitle: 'Envio concluído',
            successMessage: 'O serviço foi enviado para Urlink com sucesso.',
            errorTitle: 'Erro',
            errorMessage: 'Ocorreu um erro ao enviar o serviço para Urlink.'
        },
        es: {
            validationTitle: 'Faltan campos obligatorios',
            validationSummary: 'Hay {0} campos obligatorios por completar antes de enviar a Urlink.',
            validationFieldsLabel: 'Campos pendientes: {0}',
            successTitle: 'Envío completado',
            successMessage: 'El servicio se ha enviado a Urlink correctamente.',
            errorTitle: 'Error',
            errorMessage: 'Se ha producido un error al enviar el servicio a Urlink.'
        },
        en: {
            validationTitle: 'Missing mandatory fields',
            validationSummary: 'There are {0} mandatory fields to complete before sending to Urlink.',
            validationFieldsLabel: 'Missing fields: {0}',
            successTitle: 'Sent successfully',
            successMessage: 'The service was sent to Urlink successfully.',
            errorTitle: 'Error',
            errorMessage: 'An error occurred while sending the service to Urlink.'
        }
    };

    @api
    async invoke() {
        try {
            if (!this.recordId) {
                throw new Error(this.text('errorMessage'));
            }

            const missingFields = await validateMandatoryFields({ recordId: this.recordId });

            if (missingFields?.length) {
                this.showValidationToast(missingFields);
                return;
            }

            const result = await createServiceFromButton({ orderId: this.recordId });

            if (!result?.success) {
                this.showToast(
                    this.text('errorTitle'),
                    result?.message || this.text('errorMessage'),
                    'error',
                    'sticky'
                );
                return;
            }

            this.showToast(
                this.text('successTitle'),
                result?.message || this.text('successMessage'),
                'success'
            );
            await this.refreshPage();

            window.setTimeout(() => {
                this.dispatchEvent(new CloseActionScreenEvent());
            }, 1500);
        } catch (error) {
            this.showToast(
                this.text('errorTitle'),
                error?.body?.message || this.text('errorMessage'),
                'error'
            );
            await this.refreshPage();
        }
    }

    showValidationToast(missingFields) {
        const total = missingFields.length;
        const fieldLabels = missingFields.map((fieldKey) => this.getFieldLabel(fieldKey)).join(', ');
        const message = [
            this.format(this.text('validationSummary'), [total]),
            this.format(this.text('validationFieldsLabel'), [fieldLabels])
        ].join(' ');

        this.showToast(
            this.text('validationTitle'),
            message,
            'error',
            'sticky'
        );
    }

    showToast(title, message, variant, mode = 'dismissable') {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
                mode
            })
        );
    }

    /**
     * Best-effort refresh for Quick Actions.
     * Some containers don't support `RefreshEvent` and can throw; never let refresh break the success path.
     */
    async refreshPage() {
        if (this.recordId) {
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (e) {
                // ignore
            }

            try {
                getRecordNotifyChange([{ recordId: this.recordId }]);
            } catch (e) {
                // ignore
            }
        }

        try {
            this.dispatchEvent(new RefreshEvent());
        } catch (e) {
            // ignore
        }
    }

    getFieldLabel(fieldKey) {
        const translations = this.fieldLabels[fieldKey];
        if (!translations) {
            return fieldKey;
        }

        return translations[this.language] || translations.en;
    }

    text(key) {
        return this.messages[this.language]?.[key] || this.messages.en[key];
    }

    format(template, values = []) {
        return values.reduce(
            (result, value, index) => result.replace(`{${index}}`, value),
            template
        );
    }

    get language() {
        const normalizedLanguage = (LANG || 'en').toLowerCase();

        if (normalizedLanguage.startsWith('pt')) {
            return 'pt';
        }

        if (normalizedLanguage.startsWith('es')) {
            return 'es';
        }

        return 'en';
    }
}