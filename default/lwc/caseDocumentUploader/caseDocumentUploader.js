import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import uploadDocuments from '@salesforce/apex/CaseDocumentUploaderController.uploadDocuments';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import DOCUMENT_CHANNEL from '@salesforce/messageChannel/documentChannel__c';
import { publish, MessageContext } from 'lightning/messageService';
import AddDocuments from "@salesforce/label/c.AddDocuments";
import RelatedCase from "@salesforce/label/c.RelatedCase";
import DocumentaryType from "@salesforce/label/c.DocumentaryType";
import Comments from "@salesforce/label/c.Comments";
import SelectFiles from "@salesforce/label/c.SelectFiles";
import AddedFiles from "@salesforce/label/c.AddedFiles";
import Remove from "@salesforce/label/c.Remove";
import AddToList from "@salesforce/label/c.AddToList";
import Success from "@salesforce/label/c.Success";
import Error from "@salesforce/label/c.Error";
import FilesSuccessfullyUploaded from "@salesforce/label/c.FilesSuccessfullyUploaded";
import 	FailureToUploadFiles from "@salesforce/label/c.FailureToUploadFiles";
import SearchTasks from "@salesforce/label/c.SearchTasks";
import ContactRecord from "@salesforce/label/c.ContactRecord";
import getRelatedOrders from '@salesforce/apex/CaseDocumentUploaderController.getRelatedOrders';





const CASE_FIELDS = ['Case.CaseNumber'];

const FASE_DOCUMENTAL_OPTIONS = [
    { value: 'F01', label: 'Facturas o documentos de pago' },
    { value: 'F02', label: 'Documentación adicional' },
    { value: 'F03', label: 'Documentación Proveedores' },
    { value: 'F04', label: 'Documentación Judicial' },
    { value: 'F05', label: 'Documentación VTS' },
    { value: 'F06', label: 'Comunicaciones Diversos' }
];

// All Tipo Documental options: label = Descripción shown to user, value = Código saved to Apex
const ALL_DOC_TYPES = [
    { value: 'T01001', label: 'Facturas asegurado' },
    { value: 'T01002', label: 'Presupuesto asegurado' },
    { value: 'T01003', label: 'Minutas perito' },
    { value: 'T01004', label: 'Facturas reparador' },
    { value: 'T01005', label: 'Facturas Otros Colaboradores' },
    { value: 'T01006', label: 'Justificantes de pago' },
    { value: 'T02001', label: 'Informes Meteorología' },
    { value: 'T02002', label: 'Escrituras vivienda' },
    { value: 'T02003', label: 'Denuncias Robo/Actos Vandálicos' },
    { value: 'T02004', label: 'Fotografías del asegurado' },
    { value: 'T02005', label: 'Declaración del contrario' },
    { value: 'T02006', label: 'Otra documentación' },
    { value: 'T03001', label: 'Albaranes' },
    { value: 'T03002', label: 'Fotografías colaborador' },
    { value: 'T03003', label: 'Informe pericial Diversos' },
    { value: 'T03004', label: 'Ordenes de trabajo' },
    { value: 'T03005', label: 'Parte de trabajo' },
    { value: 'T04001', label: 'Documentación judicial' },
    { value: 'T05001', label: 'Documentos Varios VTS' },
    { value: 'T05002', label: 'Informe investigación VTS' },
    { value: 'T05003', label: 'Mail VTS' },
    { value: 'T05004', label: 'Llamadas VTS' },
    { value: 'T05005', label: 'Videos VTS' },
    { value: 'T05006', label: 'Fotografías VTS' },
    { value: 'T06001', label: 'Comunicaciones de clientes' },
    { value: 'T06002', label: 'Comunicaciones a cliente Corrosión o Rehúse' },
    { value: 'T06003', label: 'Comunicaciones a cliente Propuesta indemnización' },
    { value: 'T06004', label: 'Comunicaciones Enviadas' },
    { value: 'T06005', label: 'Emails internos' },
    { value: 'T06006', label: 'Reclamaciones de clientes' },
    { value: 'T06007', label: 'Incidencias/Reclamaciones GISS' },
    { value: 'T06008', label: 'SMS recibido' },
    { value: 'T06009', label: 'SMS a cliente' },
    { value: 'T06010', label: 'Mail a cliente' },
    { value: 'T06011', label: 'Resolución SAC/DEC' },
    { value: 'T06012', label: 'Fotografías perjudicado' },
    { value: 'T06013', label: 'Informes/Certificado Cia. Eléctrica' },
    { value: 'T06014', label: 'Informes periciales cia. Contraria' },
    { value: 'T06015', label: 'Documentación/Reclamación Contrario' },
    { value: 'T06016', label: 'Cartas de reclamación de cia contraria' },
    { value: 'T06017', label: 'Doc. adjuntada por el mediador' },
    { value: 'T06018', label: 'WhatsApp' }
];

// Static mapping: Familia Documental code -> array of Tipo Documental codes
// F01=Facturas o documentos de pago, F02=Documentación adicional,
// F03=Documentación Proveedores, F04=Documentación Judicial,
// F05=Documentación VTS, F06=Comunicaciones Diversos
const DOCS_BY_FASE = {
    'F01': [
        'T01001', // Facturas asegurado
        'T01002', // Presupuesto asegurado
        'T01003', // Minutas perito
        'T01004', // Facturas reparador
        'T01005', // Facturas Otros Colaboradores
        'T01006'  // Justificantes de pago
    ],
    'F02': [
        'T02001', // Informes Meteorología
        'T02002', // Escrituras vivienda
        'T02003', // Denuncias Robo/Actos Vandálicos
        'T02004', // Fotografías del asegurado
        'T02005', // Declaración del contrario
        'T02006'  // Otra documentación
    ],
    'F03': [
        'T03001', // Albaranes
        'T03002', // Fotografías colaborador
        'T03003', // Informe pericial Diversos
        'T03004', // Ordenes de trabajo
        'T03005'  // Parte de trabajo
    ],
    'F04': [
        'T04001'  // Documentación judicial
    ],
    'F05': [
        'T05001', // Documentos Varios VTS
        'T05002', // informe investigación VTS
        'T05003', // Mail VTS
        'T05004', // Llamadas VTS
        'T05005', // Videos VTS
        'T05006'  // Fotografías VTS
    ],
    'F06': [
        'T06001', // Comunicaciones de clientes
        'T06002', // Comunicaciones a cliente Corrosión o Rehúse
        'T06003', // Comunicaciones a cliente Propuesta indemnización
        'T06004', // Comunicaciones Enviadas
        'T06005', // emails internos
        'T06006', // Reclamaciones de clientes
        'T06007', // Incidencias/Reclamaciones GISS
        'T06008', // SMS recibido
        'T06009', // SMS a cliente
        'T06010', // Mail a cliente
        'T06011', // Resolución SAC/DEC
        'T06012', // Fotografías perjudicado
        'T06013', // Informes/Certificado Cia. Eléctrica
        'T06014', // Informes periciales cia. Contraria
        'T06015', // Documentación/Reclamación Contrario
        'T06016', // Cartas de reclamación de cia contraria
        'T06017', // Doc. adjuntada por el mediador
        'T06018'  // WhatsApp
    ]
};

export default class CaseDocumentUploader extends LightningElement {
    @api recordId;

    caseNumber;
    tipoDocumental = '';
    description = '';
    files = [];
    @track documentTypeOptions = [];
    @track faseDocumentalOptions = [];
    @track faseDocumental = '';

    label = {
        AddDocuments,
        RelatedCase,
        DocumentaryType,
        Comments,
        SelectFiles,
        AddedFiles,
        Remove,
        AddToList,
        Success,
        Error,
        FilesSuccessfullyUploaded,
        FailureToUploadFiles,
        SearchTasks,
        ContactRecord
    };

    linkedEntityId;








    /* ---------- GETTERS ---------- */
    get hasFiles() {
        return this.files.length > 0;
    }

    get linkedEntityLabel() {
        if (!this.recordId) {
            return this.label.RelatedCase;
        }
        // Case/Order: starts with 500 or 801
        if (this.recordId.startsWith('500') || this.recordId.startsWith('801')) {
            return this.label.RelatedCase;
        }
        // Task: starts with 00T
        if (this.recordId.startsWith('00T')) {
            return this.label.SearchTasks;
        }
        // Contact: starts with 003
        if (this.recordId.startsWith('003')) {
            return this.label.ContactRecord;
        }
        // Default
        return this.label.RelatedCase;
    }

    get isUploadDisabled() {
        return !this.tipoDocumental || !this.linkedEntityId || this.files.length === 0;
    }

    /* ---------- CASE ---------- */
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    wiredCase({ data }) {
        if (data) {
            this.caseNumber = data.fields.CaseNumber.value;
        }
    }
    @wire(MessageContext)
    messageContext;





    /* ---------- INPUTS ---------- */
    handleTipoDocumental(event) {
        this.tipoDocumental = event.target.value;
    }

    handleDescription(event) {
        this.description = event.target.value;
    }

    /* ---------- FILES ---------- */
    handleFilesChange(event) {
        const selectedFiles = Array.from(event.target.files);

        const newFiles = selectedFiles.map(file => ({
            key: `${file.name}-${file.size}-${file.lastModified}`,
            file: file,
            name: file.name
        }));

        this.files = [...this.files, ...newFiles];
        event.target.value = null;
    }

    connectedCallback() {
        this.loadRelatedOrders();
        this.faseDocumentalOptions = [...FASE_DOCUMENTAL_OPTIONS];
        // Initialize document type options with full static list
        this.documentTypeOptions = [...ALL_DOC_TYPES];
    }
    

    async loadFaseDocumental() {
        // Este método já não é necessário
    }

    handleFaseDocumentalChange(event) {
        this.faseDocumental = event.detail.value;
        this.tipoDocumental = '';
        console.log('Fase selecionada:', this.faseDocumental);
        this.filterDocumentalTypesByFase();
    }

    filterDocumentalTypesByFase() {
        if (!this.faseDocumental) {
            this.documentTypeOptions = [...ALL_DOC_TYPES];
            return;
        }

        // The faseDocumental value is the F-code (e.g. 'F01').
        // Filter the static ALL_DOC_TYPES list by the allowed T-codes.
        const allowedCodes = DOCS_BY_FASE[this.faseDocumental];
        console.debug('filterDocumentalTypesByFase - fase:', this.faseDocumental, 'allowedCodes:', allowedCodes);

        if (allowedCodes && allowedCodes.length > 0) {
            const allowedSet = new Set(allowedCodes.map(c => c.toUpperCase()));
            this.documentTypeOptions = ALL_DOC_TYPES.filter(e => allowedSet.has(e.value.toUpperCase()));
            console.debug('filterDocumentalTypesByFase - results:', this.documentTypeOptions.length);
        } else {
            // No mapping for this fase — show all
            console.warn('No DOCS_BY_FASE mapping for fase:', this.faseDocumental, '— showing all document types');
            this.documentTypeOptions = [...ALL_DOC_TYPES];
        }
    }

    // loadDocumentalType removed: filtering handled client-side via UI API wires

    async loadRelatedOrders() {
        try {
            console.log('Carregando entidades relacionadas para recordId:', this.recordId);
            const result = await getRelatedOrders({ caseId: this.recordId });
            console.log('Entidades relacionadas carregadas:', result);
            this.relatedOrdersOptions = result || [];
            if (this.relatedOrdersOptions.length > 0) {
                this.linkedEntityId = this.relatedOrdersOptions[0].value;
                console.log('EntidadeId padrão selecionada:', this.linkedEntityId);
            }
        } catch (error) {
            console.error('Erro ao buscar entidades relacionadas:', error);
            this.relatedOrdersOptions = [];
        }
    }

    handleLinkedEntityChange(event) {
        this.linkedEntityId = event.detail.value;
    }




    notifyDocumentUploaded() {
        const message = { refresh: true };
        publish(this.messageContext, DOCUMENT_CHANNEL, message);
    }


    handleRemoveFile(event) {
        const index = Number(event.currentTarget.dataset.index);
        this.files = this.files.filter((_, i) => i !== index);
    }

    /* ---------- UPLOAD ---------- */
    async handleUpload() {
        if (!this.files.length) {
            return;
        }

        // Validação: documentType é required
        if (!this.tipoDocumental || this.tipoDocumental.trim() === '') {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: this.label.Error,
                    message: 'Documentary Type é obrigatório!',
                    variant: 'error'
                })
            );
            return;
        }

        try {
            const payload = await Promise.all(
                this.files.map(item => this.readFile(item.file))
            );

            await uploadDocuments({
                caseId: this.recordId,
                tipoDocumental: this.tipoDocumental,
                description: this.description,
                files: payload,
                linkedEntityId: this.linkedEntityId,
                faseDocumental: this.faseDocumental
            });

            // reset após sucesso
            this.files = [];
            this.tipoDocumental = '';
            this.description = '';

            // Toast de sucesso
            this.dispatchEvent(
                new ShowToastEvent({
                    title: this.label.Success,
                    message: this.label.FilesSuccessfullyUploaded,
                    variant: 'success'
                })
            );
            
            this.notifyDocumentUploaded();

        } catch (error) {
            console.error('Erro no upload:', error);
            // Toast de erro
            this.dispatchEvent(
                new ShowToastEvent({
                    title: this.label.Error,
                    message: this.label.FailureToUploadFiles,
                    variant: 'error'
                })
            );
        }
    }

    readFile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();

            reader.onload = () => {
                const result = reader.result;
                let base64Data;

                if (typeof result === 'string' && result.includes(',')) {
                    base64Data = result.split(',')[1];
                } else {
                    reject(new Error('Erro a ler ficheiro: formato inválido'));
                    return;
                }

                resolve({
                    fileName: file.name,
                    base64Data: base64Data
                });
            };

            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });
    }
}