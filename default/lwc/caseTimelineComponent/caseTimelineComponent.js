/**
 * @description       : 
 * @author            : Afonso Duque
 * @group             : 
 * @last modified on  : 12-02-2026
 * @last modified by  : Afonso Duque
**/
import { LightningElement, api, wire } from 'lwc';
import GET_ACTIVITIES from '@salesforce/apex/CaseTimelineController.getActivities';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import BOOKMARK_FIELD from '@salesforce/schema/Case.Favorites__c';
import { refreshApex } from '@salesforce/apex';

import ORDER_OBJECT from '@salesforce/schema/Order';
import ORDER_HISTORY_OBJECT from '@salesforce/schema/OrderHistory';
import SERVICE_OBJECT from '@salesforce/schema/Service__c';
import SERVICE_HISTORY_OBJECT from '@salesforce/schema/Service__History';
import INCIDENT_OBJECT from '@salesforce/schema/Incident';
import CASE_HISTORY_OBJECT from '@salesforce/schema/CaseHistory';
import STAKEHOLDERS_OBJECT from '@salesforce/schema/Stakeholders__c';

import Hitos from '@salesforce/label/c.Milestones';
import Favoritos from '@salesforce/label/c.Favorites';
import Events from '@salesforce/label/c.Events';		
import Approvalhistory from '@salesforce/label/c.ApprovalHistory';
import Comentarios from '@salesforce/label/c.Comments';
import CaseHistory from '@salesforce/label/c.CaseHistory';
import Services from '@salesforce/label/c.Services';
import Task from '@salesforce/label/c.Task';
import TimeLineActivities from '@salesforce/label/c.TimelineActivities';
import DateRange from '@salesforce/label/c.DateRange';
import Start from '@salesforce/label/c.Start';
import End from '@salesforce/label/c.End';
import ObjectsDisplay from '@salesforce/label/c.ObjectsDisplay';
import DeselectAll from '@salesforce/label/c.DeselectAll';
import SelectAll from '@salesforce/label/c.SelectAll';
import Apply from '@salesforce/label/c.Apply';
import MarkFavorite from '@salesforce/label/c.MarkFavorite';
import RemoveMarker from '@salesforce/label/c.MarkFavorite';
import To from '@salesforce/label/c.To';
import ShowAll from '@salesforce/label/c.Showall';
import Reply from '@salesforce/label/c.Reply';
import MoreOptions from '@salesforce/label/c.MoreOptions';
import OpenClose from '@salesforce/label/c.OpenClose';
import RemovedFromFavorites from '@salesforce/label/c.RemovedFromFavorites';
import ErrorRemovingFavorite from '@salesforce/label/c.ErrorRemovingFavorite';
import MarkedAsFavorite from '@salesforce/label/c.MarkedAsFavorite';
import ErrorMarkingAsFavorite from '@salesforce/label/c.ErrorMarkingAsFavorite';
import Stakeholders from '@salesforce/label/c.Stakeholders';
import Name from '@salesforce/label/c.Name';
import Search from '@salesforce/label/c.Search';

export default class CaseTimelineComponent extends LightningElement {

	@api recordId;
	ativeActivityId = true;
	closeDropDown = true;
	loading = true;
	loadingSpinnerActions = false;
	openFilters = false;
	allSelected = false;
	today = new Date();
	startDate = new Date(new Date().setMonth(this.today.getMonth() - 12)).toISOString();
	endDate = new Date().toISOString();
	allActivities = [];
	filteredActivities = [];
	TimelineAtividades = TimeLineActivities;
	DateRange = DateRange;
	Start = Start;
	End = End;
	ObjectsDisplay = ObjectsDisplay;
	DeselectAll = DeselectAll;
	SelectAll = SelectAll;
	Apply = Apply;
	MarkFavorite = MarkFavorite;
	RemoveMarker = RemoveMarker;
	To = To + ":";
	ShowAll = ShowAll;
	Reply = Reply;
	MoreOptions = MoreOptions;
	OpenClose = OpenClose;
	Name = Name;
	searchText = '';
	searchPlaceholder = Search + '...';
	allExpanded = false;

	@wire(getObjectInfo, { objectApiName: ORDER_OBJECT })
	orderInfo;
	@wire(getObjectInfo, { objectApiName: ORDER_HISTORY_OBJECT })
	orderHistoryInfo;
	@wire(getObjectInfo, { objectApiName: SERVICE_OBJECT })
	serviceInfo;
	@wire(getObjectInfo, { objectApiName: SERVICE_HISTORY_OBJECT })
	serviceHistoryInfo;
	@wire(getObjectInfo, { objectApiName: INCIDENT_OBJECT })
	incidentInfo;
	@wire(getObjectInfo, { objectApiName: CASE_HISTORY_OBJECT })
	caseHistoryInfo;
	@wire(getObjectInfo, { objectApiName: STAKEHOLDERS_OBJECT })
	stakeholdersInfo;

	get objects() {
		const orderLabel = this.orderInfo?.data?.label || Services;
		const orderHistoryLabel = this.orderHistoryInfo?.data?.label || 'OrderHistory';
		const serviceLabel = this.serviceInfo?.data?.label || 'Service';
		const serviceHistoryLabel = this.serviceHistoryInfo?.data?.label || 'Service__History';
		const incidentLabel = this.incidentInfo?.data?.label || 'Incident';
		const caseHistoryLabel = this.caseHistoryInfo?.data?.label || CaseHistory;
		const stakeholdersLabel = this.stakeholdersInfo?.data?.label || Stakeholders;

		return [
			{
				label: Favoritos,
				value: 'Favorites'
			},
			{
				label: Comentarios,
				value: 'Comments__c'
			},
			{
				label: Hitos,
				value: 'Hitos'
			},
			{
				label: stakeholdersLabel,
				value: 'Stakeholders__c'
			},
			{
				label: 'E-mails',
				value: 'EmailMessage'
			},
			{
				label: Events,
				value: 'Event'
			},
			{
				label: Approvalhistory,
				value: 'ProcessInstanceHistory'
			},
			{
				label: caseHistoryLabel,
				value: 'CaseHistory'
			},
			{
				label: orderLabel,
				value: 'Order'
			},
			{
				label: Task,
				value: 'Task'
			},
			{
				label: orderHistoryLabel,
				value: 'OrderHistory'
			},
			{
				label: serviceLabel,
				value: 'Service__c'
			},
			{
				label: serviceHistoryLabel,
				value: 'Service__History'
			},
			{
				label: incidentLabel,
				value: 'Incident'
			}
		];
	}
	selectedObjects = [];
	bigField = true;

	@wire(getRecord, { recordId: '$recordId', fields: [BOOKMARK_FIELD] })
	caso;

	get nubbinClass() {
		return this.openFilters
			? 'slds-nubbin_top-right uiPanel--default uiPanel positioned south active show'
			: 'slds-nubbin_top-right uiPanel--default uiPanel positioned south active hide';
	}

	connectedCallback() {
		console.log('connectedCallback');
		this.selectAll();
		this.getActivities();
	}

	getActivities() {
		this.loading = true;
		let filters = {
			startDate: this.startDate,
			endDate: this.endDate,
			selectedObjets: this.selectedObjects
		};

		GET_ACTIVITIES({ caseId: this.recordId, filter: filters })
			.then((result) => {
				console.log(result);
				this.allActivities = result;
				this.filteredActivities = this.filterActivities();
				this.loading = false;
			})
			.catch((error) => {
				console.error(error);
				this.loading = false;

				this.dispatchEvent(
					new ShowToastEvent({
						title: 'Timeline error',
						message: error.body.message,
						variant: 'error'
					})
				);
			});
	}

	renderedCallback() {
		const style = document.createElement('style');
		style.innerText += `lightning-card[c-lwc_timeline_lwc_timeline]>article {border: 1px solid rgb(201, 201, 201) !important;box-shadow: 0 2px 2px 0 rgba(0, 0, 0, 0.10) !important;}`;
		style.innerText += `lightning-card[c-lwc_timeline_lwc_timeline]>article > .slds-card__header {padding: .75rem !important;background: var(--lwc-pageHeaderColorBackground,rgb(243, 243, 243));background-clip: padding-box;border-bottom-left-radius: 0;border-bottom-right-radius: 0;border-bottom: 1px solid rgb(201, 201, 201);}`;
		this.template.querySelector('lightning-card').appendChild(style);
	}

	toggleFilters() {
		this.openFilters = !this.openFilters;
	}

	handleSearchInput(e) {
		this.loading = true;
		this.searchText = e.target.value;
		this.filteredActivities = this.filterActivities();
		this.loading = false;
	}

	filterActivities() {
		const search = (this.searchText || '').trim().toLowerCase();
		if (search) {
			return this.allActivities.filter(activity => {
				let isValid = false;
				if (!isValid && activity.createdBy) {
					isValid = (activity.createdBy.Name && activity.createdBy.Name.toLowerCase().includes(search));
				}
				if (!isValid && activity.bodyFields && Array.isArray(activity.bodyFields)){
					isValid = activity.bodyFields.some(field => {
						return field.Value && field.Value.toLowerCase().includes(search);
					});
				}
				return isValid;
			});
		} else {
			return this.allActivities;
		}
	}

	handleDates(e) {
		console.log(e);
		if (e.currentTarget.name === 'StartDate') {
			this.startDate = e.detail.value;
		} else {
			this.endDate = e.detail.value;
		}
	}

	handleObjects(e) {
		console.log(e.detail.value);
		this.selectedObjects = Object.values(e.detail.value);
		this.getActivities();
	}

	refreshWithFilters() {
		this.openFilters = false;
		refreshApex(this.caso);
		this.getActivities();
	}

	refreshAll() {
		this.openFilters = false;
		this.startDate = new Date(new Date().setMonth(this.today.getMonth() - 12)).toISOString();
		this.endDate = new Date().toISOString();
		refreshApex(this.caso);
		this.getActivities();
	}

	unSelectAll() {
		this.allSelected = false;
		this.selectedObjects = [];
	}

	selectAll() {
		this.allSelected = true;
		this.selectedObjects = [
			'Favorites',
			'Comments__c',
			'Hitos',
			'Stakeholders__c',
			'EmailMessage',
			'Event',
			'ProcessInstanceHistory',
			'CaseHistory',
			'Order',
			'Task',
			'OrderHistory',
			'Service__c',
			'Service__History',
			'Incident'
		];
	}

	expandAllActivities() {
		this.allExpanded = !this.allExpanded;
		this.template.querySelectorAll("div.slds-timeline__item_expandable").forEach(div => {
			// Find the child element with data-expand attribute
			const trigger = div.querySelector('[data-expand]');
			if (trigger && trigger.dataset.expand !== 'false') {
				if (this.allExpanded) {
					div.classList.add('slds-is-open');
				} else {
					div.classList.remove('slds-is-open');
				}
			}
		});
	}

	toggleActivity(e) {
		console.log(JSON.stringify(e.target.dataset.id));
		console.log(e);
		let activityId = e.target.dataset.id;
		console.log(e.target.dataset.expand);
		let expand = e.target.dataset.expand;
		if (expand === 'false' || activityId === undefined || expand === undefined) {
			return;
		}
		let divContainer = this.template.querySelector("div.slds-timeline__item_expandable[data-id='" + activityId + "']");
		if (divContainer.classList.contains('slds-is-open')) {
			divContainer.classList.remove('slds-is-open');
		} else {
			divContainer.classList.add('slds-is-open');
		}
	}

	toggleDropDownActions(e) {
		let activityId = e.currentTarget.dataset.id;
		this.ativeActivityId = activityId;
		let divContainer = this.template.querySelector("div.slds-dropdown-trigger_click[data-id='" + activityId + "']");
		divContainer.classList.toggle('slds-is-open');
		e.currentTarget.focus();
	}

	unmarkBookmarked(e) {
		if (e.button != 0) {
			return;
		}
		this.loadingSpinnerActions = true;
		let recordId = e.currentTarget.dataset.recordid;
		let noclose = e.currentTarget.dataset.noclose;
		//this.ativeActivityId = e.currentTarget.dataset.id;
		if (noclose === 'true') {
			this.closeDropDown = false;
		} else {
			this.closeDropDown = true;
		}

		const fields = {};
		fields.Id = this.recordId;
		fields[BOOKMARK_FIELD.fieldApiName] = this.caso.data.fields.Favorites__c.value.split(';').reduce((o, i) => {
			if (i != recordId) {
				return o + i + ';';
			} else {
				return o;
			}
		}, '');

		fields[BOOKMARK_FIELD.fieldApiName] = fields[BOOKMARK_FIELD.fieldApiName].slice(0, -1);

		const recordInput = { fields };

		updateRecord(recordInput)
			.then(() => {
				this.dispatchEvent(
					new ShowToastEvent({
						title: RemovedFromFavorites,
						variant: 'success'
					})
				);
				this.loadingSpinnerActions = false;
				this.hideDropDownActions(e, true);
				this.refreshWithFilters();
				return refreshApex(this.caso);
			})
			.catch((error) => {
				this.dispatchEvent(
					new ShowToastEvent({
						title: ErrorRemovingFavorite,
						variant: 'error'
					})
				);
			});
	}

	markBookmarked(e) {
		if (e.button != 0) {
			return;
		}
		this.loadingSpinnerActions = true;
		let recordId = e.currentTarget.dataset.recordid;
		let noclose = e.currentTarget.dataset.noclose;
		//this.ativeActivityId = e.currentTarget.dataset.id;

		if (noclose === 'true') {
			this.closeDropDown = false;
		} else {
			this.closeDropDown = true;
		}

		const fields = {};
		fields.Id = this.recordId;
		fields[BOOKMARK_FIELD.fieldApiName] =
			((this.caso.data.fields.Favorites__c.value || '') + ';' == ';' ? '' : (this.caso.data.fields.Favorites__c.value || '') + ';') + recordId;

		const recordInput = { fields };

		updateRecord(recordInput)
			.then(() => {
				this.dispatchEvent(
					new ShowToastEvent({
						title: MarkedAsFavorite,
						variant: 'success'
					})
				);
				// Display fresh data in the form
				this.loadingSpinnerActions = false;
				this.hideDropDownActions(e, true);
				this.refreshWithFilters();
				return refreshApex(this.caso);
			})
			.catch((error) => {
				this.dispatchEvent(
					new ShowToastEvent({
						title: ErrorMarkingAsFavorite,
						variant: 'error'
					})
				);
			});
	}

	hideDropDownActions(e, override) {
		if (!this.closeDropDown && !override) {
			return;
		}

		let divContainer = this.template.querySelector("div.slds-dropdown-trigger_click[data-id='" + this.ativeActivityId + "']");
		divContainer.classList.remove('slds-is-open');
		this.closeDropDown = true;

		/* setTimeout(() => {
		}, 500); */
	}

	expandEmail(e) {
		let fieldId = e.target.dataset.id;
		let btn = this.template.querySelector("span.showAll[data-id='" + fieldId + "']");
		btn.classList.add('slds-hide');
		btn.parentElement.classList.add('slds-is-open');
	}

	navigateToFiles(e) {
		let emailMessageId = e.currentTarget.dataset.id;

		this[NavigationMixin.Navigate]({
			type: 'standard__recordRelationshipPage',
			attributes: {
				recordId: emailMessageId,
				objectApiName: 'EmailMessage',
				relationshipApiName: 'CombinedAttachments',
				actionName: 'view'
			}
		});
	}

	navigate(e) {
		let recordId = e.currentTarget.dataset.id;

		/*  this.invokeWorkspaceAPI('isConsoleNavigation').then(isConsole => {
			 if (isConsole) { */
		this.invokeWorkspaceAPI('getFocusedTabInfo').then((focusedTab) => {
			this.invokeWorkspaceAPI('openSubtab', {
				parentTabId: focusedTab.tabId,
				recordId: recordId,
				focus: true
			}).then((tabId) => {
				console.log('Solution #2 - SubTab ID: ', tabId);
			});
		});
		/* }
	}); */
	}

	invokeWorkspaceAPI(methodName, methodArgs) {
		return new Promise((resolve, reject) => {
			const apiEvent = new CustomEvent('internalapievent', {
				bubbles: true,
				composed: true,
				cancelable: false,
				detail: {
					category: 'workspaceAPI',
					methodName: methodName,
					methodArgs: methodArgs,
					callback: (err, response) => {
						if (err) {
							return reject(err);
						} else {
							return resolve(response);
						}
					}
				}
			});

			window.dispatchEvent(apiEvent);
		});
	}

	openEmail(e) {
		let html = e.currentTarget.dataset.html;
		let subject = e.currentTarget.dataset.subject;
		let toaddresses = e.currentTarget.dataset.toaddresses;
		let bccaddresses = e.currentTarget.dataset.bccaddresses;

		const filterChangeEvent = new CustomEvent('openemail', {
			detail: { html: html, subject: subject, toaddresses: toaddresses, bccaddresses: bccaddresses }
		});
		// Fire the custom event
		this.dispatchEvent(filterChangeEvent);
	}
}