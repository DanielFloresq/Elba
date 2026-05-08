/**
 * @description       : 
 * @author            : Tiago Pereira
 * @group             : 
 * @last modified on  : 04-02-2026
 * @last modified by  : Afonso Duque
**/
import { LightningElement, api, wire, track } from "lwc";
import { CloseActionScreenEvent } from "lightning/actions";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import CONTACTID_FIELD from "@salesforce/schema/Case.ContactId";
import GRAN_ACCOUNT_FIELD from "@salesforce/schema/Case.GrandAccount__c";
import getTemplates from "@salesforce/apex/gerarCartaPdfController.getTemplates";
import mergeTemplate from "@salesforce/apex/gerarCartaPdfController.mergeTemplate";
import saveHtmlTemplate from "@salesforce/apex/gerarCartaPdfController.saveHtmlTemplate";
import createPdf from "@salesforce/apex/gerarCartaPdfController.createPdf";
import { loadStyle } from "lightning/platformResourceLoader";
import modalWidth from "@salesforce/resourceUrl/ModalWidth";
import modalWidthReset from "@salesforce/resourceUrl/ModalWidthReset";
import LabelLoading from "@salesforce/label/c.GerarCarta_Loading";
import LabelTemplate from "@salesforce/label/c.GerarCarta_TemplateLabel";
import LabelSelectTemplate from "@salesforce/label/c.GerarCarta_SelectTemplate";
import LabelJustify from "@salesforce/label/c.GerarCarta_Justify";
import LabelJustifyText from "@salesforce/label/c.GerarCarta_JustifyText";
import LabelNext from "@salesforce/label/c.GerarCarta_Next";
import LabelCancel from "@salesforce/label/c.GerarCarta_Cancel";
import LabelSave from "@salesforce/label/c.GerarCarta_Save";
import LabelPrevious from "@salesforce/label/c.GerarCarta_Previous";
import LabelErrorTitle from "@salesforce/label/c.GerarCarta_ErrorTitle";
import LabelErrorGeneric from "@salesforce/label/c.GerarCarta_ErrorGeneric";
import LabelSuccessTitle from "@salesforce/label/c.GerarCarta_SuccessTitle";
import LabelPdfCreated from "@salesforce/label/c.GerarCarta_PdfCreated";


const fields = [CONTACTID_FIELD, GRAN_ACCOUNT_FIELD];
const BODY_CLASS_STEP_1 = "gerar-carta-step-1";
const BODY_CLASS_STEP_2 = "gerar-carta-step-2";

export default class GerarCartaPdfCmp extends LightningElement {
	//#region variaveis
	@api recordId;

	@track options = [];

	selectedValue;
	selectedLabel;
	loadedTemplates = false;
	showSpinner = true;
	editTemplate = false;
	@track templateHtml = "";
	nextBtnLabel = LabelNext;
	nextDisabled = true;
	previousBtnLabel = LabelCancel;
	step = 1;
	firstLoadHtml = true;
	styleString = "";
	string = '<div style= "text-align: justify;"> ';
	justifySelected = false;
	isComboboxOpen = false;
	labels = {
		loading: LabelLoading,
		template: LabelTemplate,
		selectTemplate: LabelSelectTemplate,
		justify: LabelJustify
	};

	stringend = " </div>";
	customButtons = [
		{
			category: "ALIGN_TEXT",
			label: LabelJustifyText,
			selected: true,
			buttons: [
				{
					value: LabelJustifyText,
					label: LabelJustify,
					iconName: "utility:justify_text",
					selected: true,
					format: "align",
					handler: function () {
						console.log(this);
						const editor = this.template.querySelector(
							"lightning-input-rich-text"
						);
						console.log(editor.getFormat());
						editor.setFormat({ align: "justify" });
					}.bind(this)
				}
			]
		}
	];

	appliedFormats = {
		font: "sans-serif",
		size: 35
	};

	//#endregion

	// Apply step-specific body classes to control modal sizing.
	applyStepClass(step) {
		document.body.classList.remove(BODY_CLASS_STEP_1, BODY_CLASS_STEP_2);
		if (step === 1) {
			document.body.classList.add(BODY_CLASS_STEP_1);
		} else if (step === 2) {
			document.body.classList.add(BODY_CLASS_STEP_2);
		}
	}

	//#region wire
	@wire(getRecord, { recordId: "$recordId", fields })
	case;

	// Get the Contact Id from the Case record.
	get contactId() {
		return getFieldValue(this.case.data, CONTACTID_FIELD);
	}

	// Get the GrandAccount__c value from the Case record.
	get grandAccount() {
		return getFieldValue(this.case.data, GRAN_ACCOUNT_FIELD);
	}

	@wire(getTemplates, { grandAccount: '$grandAccount' })
	wiredData({ error, data }) {
		// Load available templates into the combobox.
		if (data) {
			data.forEach((element) => {
				this.options.push({ label: element.Name, value: element.Id });
			});
			this.loadedTemplates = true;
			this.showSpinner = false;
		} else if (error) {
			console.error("Error:", error);
			this.showToast(LabelErrorTitle, error, "error");
		}
	}
	//#endregion

	// Toggle justify/left alignment on the rich text editor.
	textJustify() {
		const editor = this.template.querySelector("lightning-input-rich-text");
		let format = editor.getFormat();
		if (format.align === "justify") {
			this.justifySelected = false;
			editor.setFormat({ align: "left" });
		} else {
			this.justifySelected = true;
			editor.setFormat({ align: "justify" });
		}
	}

	// Sync justify button state with editor alignment.
	handleMouseDown() {
		const editor = this.template.querySelector("lightning-input-rich-text");
		let format = editor.getFormat();
		if (format.align === "justify") {
			this.justifySelected = true;
		} else {
			this.justifySelected = false;
		}
	}
	// Capture the initial HTML from the editor once.
	renderedCallback() {
		let editor = this.template.querySelector("lightning-input-rich-text");
		if (editor && this.firstLoadHtml) {
			this.templateHtml = editor.value;
			this.firstLoadHtml = false;
		}
	}

	// Handle template selection changes.
	handlePicklistChange(event) {
		this.selectedValue = event.detail.value;
		this.selectedLabel = event.target.options.find(
			(opt) => opt.value === event.detail.value
		).label;
		if (this.selectedValue) {
			this.nextDisabled = false;
		}
	}

	// Track combobox open state on focus.
	handleComboboxFocus() {
		this.isComboboxOpen = true;
	}

	// Track combobox open state on blur.
	handleComboboxBlur() {
		this.isComboboxOpen = false;
	}

	// Provide spacing so the combobox dropdown fits without clipping.
	get picklistSpacerStyle() {
		if (!this.isComboboxOpen || !this.options || this.options.length === 0) {
			return "height:0px;";
		}
		const rowHeight = 32;
		const padding = 8;
		const height = this.options.length * rowHeight + padding;
		return `height:${height}px;`;
	}

	// Close the quick action and clean body classes.
	closeAction() {
		document.body.classList.remove(BODY_CLASS_STEP_1, BODY_CLASS_STEP_2);
		this.dispatchEvent(new CloseActionScreenEvent());
	}

	// Advance to the next step or save.
	nextStep() {
		this.firstLoadHtml = true;
		if (this.step == 1) {
			this.showEditTemplate();
		} else if (this.step == 2) {
			this.saveHtml();
		}
	}

	// Go back a step or close the action.
	previousStep() {
		this.firstLoadHtml = true;
		if (this.step == 1) {
			this.closeAction();
		} else if (this.step == 2) {
			this.showComboTemplate();
		}
	}

	// Persist the edited HTML on the Case.
	saveHtml() {
		this.showSpinner = true;
		saveHtmlTemplate({ caseId: this.recordId, html: this.templateHtml })
			.then((result) => {
				if (result && result.success) {
					this.createFilePdf(result.caseNumber);
				} else {
					this.showToast(LabelErrorTitle, LabelErrorGeneric, "error");
				}
			})
			.catch((error) => {
				// TODO Error handling
				this.showToast(LabelErrorTitle, error, "error");
			});
	}

	// Generate the PDF and show a clickable success toast.
	createFilePdf(ncaso) {
		createPdf({
			caseId: this.recordId,
			caseNumber: ncaso,
			templateName: this.selectedLabel
		})
			.then((result) => {
				if (result && result.contentDocumentId) {
					this.step = 1;
					this.selectedValue = null;
					this.nextDisabled = true;
					this.showToastLink(
						LabelSuccessTitle,
						LabelPdfCreated,
						"success",
						result.title,
						result.contentDocumentId
					);
					this.showSpinner = false;
					this.showComboTemplate();
				}
			})
			.catch((error) => {
				// TODO Error handling
				this.showToast(LabelErrorTitle, error, "error");
			});
	}

	// Load the selected template and show the editor step.
	showEditTemplate() {
		this.showSpinner = true;
		this.loadedTemplates = false;
		this.applyStepClass(2);
		mergeTemplate({
			templateId: this.selectedValue,
			contactId: this.contactId,
			caseId: this.recordId
		})
			.then((result) => {
				this.nextBtnLabel = LabelSave;
				this.previousBtnLabel = LabelPrevious;
				this.templateHtml = result;
				loadStyle(this, modalWidth);
				this.editTemplate = true;
				this.showSpinner = false;
				this.step = 2;
			})
			.catch((error) => {
				// TODO Error handling
				console.log(error);
				this.showToast(LabelErrorTitle, error, "error");
			});
	}

	// Track HTML edits from the rich text editor.
	handleChangeHtml(event) {
		this.templateHtml = event.target.value;
		console.log(this.templateHtml);
	}

	// Return to the template selection step.
	showComboTemplate() {
		loadStyle(this, modalWidthReset);
		this.showSpinner = true;
		this.editTemplate = false;
		this.previousBtnLabel = LabelCancel;
		this.nextBtnLabel = LabelNext;
		this.loadedTemplates = true;
		this.showSpinner = false;
		this.step = 1;
		this.applyStepClass(1);
	}

	// Cleanup body classes when component is destroyed.
	disconnectedCallback() {
		document.body.classList.remove(BODY_CLASS_STEP_1, BODY_CLASS_STEP_2);
	}

	// Show a standard toast message.
	showToast(title, message, variant) {
		const evt = new ShowToastEvent({
			title: title,
			message: message,
			variant: variant,
			mode: "dismissable",
			duration: 10000
		});
		this.dispatchEvent(evt);
	}

	// Show a toast with a clickable link to the created document.
	showToastLink(title, message, variant, linkLabel, contentDocumentId) {
		const url = `/lightning/r/ContentDocument/${contentDocumentId}/view`;
		const evt = new ShowToastEvent({
			title: title,
			message: message,
			messageData: [{ url, label: linkLabel }],
			variant: variant,
			mode: "dismissable",
			duration: 10000
		});
		this.dispatchEvent(evt);
	}
}