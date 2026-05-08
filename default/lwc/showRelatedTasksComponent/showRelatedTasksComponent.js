/**
 * @description       :
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 30-04-2026
 * @last modified by  : Daniel Flores
**/
import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getRelatedTasks from '@salesforce/apex/RelatedTasksController.getRelatedTasks';
import { refreshApex } from '@salesforce/apex';
import USER_ID from '@salesforce/user/Id';
import createParentTask from '@salesforce/apex/RelatedTasksController.createParentTask';
import getRecordInfo from '@salesforce/apex/RelatedTasksController.getRecordInfo';
import getRelatedServicesInfo from '@salesforce/apex/RelatedTasksController.getRelatedServicesInfo';
import getRelatedOrdersInfo from '@salesforce/apex/RelatedTasksController.getRelatedOrdersInfo';
//import getSubjectSuggestions from '@salesforce/apex/RelatedTasksController.getSubjectSuggestions';
import getTaskMetadata from '@salesforce/apex/RelatedTasksController.getCreateTaskMetadata';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/User.Name';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import TaskLabel from '@salesforce/label/c.Task';

export default class ShowRelatedTasksComponent extends NavigationMixin(LightningElement) {
    @api recordId;
    loading = true;
    error;
    taskGroups = [];
    expandedTaskIds = [];
    allExpanded = false;
    headerLabel = 'Tareas'; // displayed label must be Spanish per requirement
    searchTerm = '';
    tasksResult;
    showCreateModal = false;
    serviceInfoMap = {}; // serviceId -> { name, type }
    orderInfoMap = {};   // orderId  -> { orderNumber, guildLabel }

    // new task form fields
    newTaskSubject = '';
    newTaskActivityDate = '';
    newTaskOwnerId = USER_ID;
    newTaskOwnerLabel = '';
    newTaskWhoId = '';
    newTaskWhatId = '';
    newTaskWhatLabel = '';
    newTaskWhatLocked = false;
    newTaskOwnerLocked = false;
    newTaskError = '';

    // Subject suggestions/autocomplete
    subjectSuggestions = [];
    showSubjectSuggestions = false;
    subjectLoading = false;
    subjectNoResults = false;
    selectedSubject = null;
    selectedParent = null;
    subjectDebounceTimer = null;
    subjectHighlightedIndex = -1;
    preventSuggestionClose = false;

    // Debug helpers visible in the UI to help troubleshooting
    lastSubjectQuery = '';
    lastSubjectResponseCount = 0;
    lastSubjectError = '';

    renderedCallback() {
        if (!this._renderedOnce) {
            console.log('showRelatedTasksComponent rendered');
            this._renderedOnce = true;
        }
    }

    expandAllActivities() {
        const shouldExpand = !this.allExpanded;
        this.allExpanded = shouldExpand;

        if (!shouldExpand) {
            this.expandedTaskIds = [];
            return;
        }

        const ids = new Set();
        (this.taskGroups || []).forEach(group => {
            if (group && group.id) {
                ids.add(group.id);
            }
            (group && group.children ? group.children : []).forEach(child => {
                if (child && child.Id) {
                    ids.add(child.Id);
                }
            });
        });

        this.expandedTaskIds = Array.from(ids);
    }
    

    taskMetadataData;
    @wire(getTaskMetadata)
    wiredTaskMetadata(response) {
        const { data, error } = response;
        this.loading = false;
        if (data) {
            this.taskMetadataData = data;
            console.log('Task metadata has data:', data);
        } else if (error) {
            console.log('Task metadata error:', error);
        }
    }

    get parentSubjectOptions() {
        // metadata is an array of records, not an object with fields
        const metadata = this.taskMetadataData;
        console.log('parentSubjectOptions metadata:', metadata);
        if (!Array.isArray(metadata) || metadata.length === 0) {
            console.log('parentSubjectOptions: metadata is empty or not an array');
            return [];
        }
        // Get unique ParentSubject__c values for the picklist
        const uniqueParents = [...new Set(metadata.map(item => item.ParentSubject__c).filter(Boolean))];
        // Get all parent subjects currently in use in taskGroupsView
        const usedSubjects = new Set((this.taskGroupsView || []).map(g => g.parent && g.parent.Subject).filter(Boolean));
        // Filter out options that are already used as parent subjects
        const options = uniqueParents
            .filter(parent => !usedSubjects.has(parent))
            .map(parent => ({ label: parent, value: parent }));
        console.log('parentSubjectOptions mapped options (filtered):', options);
        return options;
    }

    @wire(getRelatedServicesInfo, { recordId: '$recordId' })
    wiredServicesInfo({ data, error }) {
        if (data) {
            const map = {};
            data.forEach(s => { map[s.serviceId] = { name: s.serviceName, type: s.serviceType }; });
            this.serviceInfoMap = map;
            // Re-run prepareTasks if tasks are already loaded
            if (this.tasksResult && this.tasksResult.data) {
                this.prepareTasks(this.tasksResult.data);
            }
        } else if (error) {
            console.error('Error loading services info:', error);
        }
    }

    @wire(getRelatedOrdersInfo, { recordId: '$recordId' })
    wiredOrdersInfo({ data, error }) {
        if (data) {
            const map = {};
            data.forEach(o => { map[o.orderId] = { orderNumber: o.orderNumber, guildLabel: o.guildLabel }; });
            this.orderInfoMap = map;
            if (this.tasksResult && this.tasksResult.data) {
                this.prepareTasks(this.tasksResult.data);
            }
        } else if (error) {
            console.error('Error loading orders info:', error);
        }
    }

    @wire(getRelatedTasks, { recordId: '$recordId' })
    wiredTasks(response) {
        this.tasksResult = response;
        const { data, error } = response;
        this.loading = false;
        if (data) {
            this.error = undefined;
            this.prepareTasks(data);
        } else if (error) {
            this.error = error;
            this.taskGroups = [];
        }
    }

    get hasTasks() {
        // Use the filtered view so the header/footer reflects search results
        const arr = this.taskGroupsView || [];
        return arr.length > 0;
    }

    get filteredCount() {
        return (this.taskGroupsView || []).length;
    }

    @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD] })
    wiredUser({ data, error }) {
        if (data) {
            try {
                this.newTaskOwnerLabel = getFieldValue(data, NAME_FIELD) || '';
            } catch (e) {
                console.error('Error getting user name', e);
            }
        }
    }

    get taskGroupsView() {
        const term = this.searchTerm && this.searchTerm.trim().toLowerCase();
        try {
            console.log('taskGroupsView computing - term:', term, 'total groups:', (this.taskGroups || []).length);
        } catch (e) {
            console.log('Error logging taskGroupsView start:', e);
        }

        const result = (this.taskGroups || []).map(group => {
            const isExpanded = this.expandedTaskIds.includes(group.id);
            let children = (group.children || []).map(child => ({
                ...child,
                isExpanded: this.expandedTaskIds.includes(child.Id),
                expandIconName: this.expandedTaskIds.includes(child.Id) ? 'utility:chevrondown' : 'utility:chevronright'
            }));

            if (term) {
                const matchesItem = (item) => {
                    const s = `${item.Subject || ''} ${item.ownerName || ''} ${item.relatedLabel || ''} ${item.Status || ''}`;
                    return s.toLowerCase().includes(term);
                };
                const parentMatches = matchesItem(group.parent);
                const childrenMatches = children.filter(c => matchesItem(c));
                console.log('group', group.id, 'parentMatches=', parentMatches, 'childrenMatchesCount=', childrenMatches.length);
                if (!parentMatches && childrenMatches.length === 0) {
                    return null;
                }
                children = parentMatches ? children : childrenMatches;
            }

            return {
                ...group,
                isExpanded,
                children,
                containerClass: `slds-timeline__item${group.hasChildren ? '_expandable' : ''} slds-timeline__item_Task ${isExpanded ? 'slds-is-open' : ''}`,
                expandIconName: isExpanded ? 'utility:chevrondown' : 'utility:chevronright'
            };
        }).filter(g => g !== null);

        try {
            console.log('taskGroupsView computed - filtered groups:', result.length);
        } catch (e) {
            console.log('Error logging taskGroupsView end:', e);
        }
        return result;
    }

    prepareTasks(tasks) {
		console.log('prepareTasks: received tasks', tasks);
		const childrenByParent = {};
		const parents = [];
		tasks.forEach(task => {
			// Debug: list own keys and iterate
			const keys = Object.keys(task || {});
			console.log('Task raw keys:', keys);
			for (let k in task) {
				console.log('Iter key:', k);
			}
			console.log('hasOwnProperty LookUpTask__c:', task ? task.hasOwnProperty('LookUpTask__c') : false, 'in operator:', task ? ('LookUpTask__c' in task) : false);

			// Try to find the key that corresponds to LookUpTask__c (case-insensitive)
			let foundKey = null;
			for (let k of keys) {
				if (k && k.toLowerCase() === 'lookuptask__c') {
					foundKey = k;
					break;
				}
			}
			if (!foundKey) {
				// try endsWith
				for (let k of keys) {
					if (k && k.toLowerCase().endsWith('lookuptask__c')) {
						foundKey = k;
						break;
					}
				}
			}
			console.log('Found key for lookup:', foundKey);

			const rawLookup = foundKey ? task[foundKey] : (task['LookUpTask__c'] !== undefined ? task['LookUpTask__c'] : (task.LookUpTask__c !== undefined ? task.LookUpTask__c : null));
			console.log('Task Id=' + task.Id + ', Subject=' + task.Subject + ', resolved rawLookup=' + JSON.stringify(rawLookup));

			const parentKey = rawLookup ? String(rawLookup) : null;
			if (parentKey) {
				if (!childrenByParent[parentKey]) {
					childrenByParent[parentKey] = [];
				}
				childrenByParent[parentKey].push(task);
			} else {
				parents.push(task);
			}
		});
		console.log('Parents (raw):', parents.map(p => p.Id));
        parents.sort((a, b) => {
            const dateA = new Date(a.CreatedDate || a.ActivityDate || 0).getTime();
            const dateB = new Date(b.CreatedDate || b.ActivityDate || 0).getTime();
            return dateB - dateA;
        });
		console.log('Children by parent (keys):', Object.keys(childrenByParent));
		console.log('Children by parent (detailed):', childrenByParent);

		this.taskGroups = parents.map(parent => {
			const children = childrenByParent[String(parent.Id)] || []; 
            children.sort((a, b) => {
                const dateA = new Date(a.CreatedDate || a.ActivityDate || 0).getTime();
                const dateB = new Date(b.CreatedDate || b.ActivityDate || 0).getTime();
                return dateB - dateA;
            });
			// Clone to plain objects to avoid proxy issues in template rendering
			const parentPlain = JSON.parse(JSON.stringify(parent));
			parentPlain.ownerName = parentPlain.Owner ? parentPlain.Owner.Name : '';
            parentPlain.relatedLabel = parentPlain.What ? parentPlain.What.Name : (parentPlain.Who ? parentPlain.Who.Name : (parentPlain.WhatId ? parentPlain.WhatId : (parentPlain.WhoId ? parentPlain.WhoId : '')));
			parentPlain.createdDate = parentPlain.CreatedDate || parent.CreatedDate || parent['CreatedDate'] || parentPlain.ActivityDate || null;
			parentPlain.displayDate = parentPlain.createdDate || parentPlain.ActivityDate || null;
			parentPlain.themeLabel = parentPlain.Theme__c || '';
			parentPlain.subthemeLabel = parentPlain.SubTheme__c || '';
			parentPlain.reminderDateTime = parentPlain.ReminderDateTime || null;
			const parentServiceInfo = parentPlain.WhatId ? this.serviceInfoMap[parentPlain.WhatId] : null;
			const parentOrderInfo = parentPlain.WhatId ? this.orderInfoMap[parentPlain.WhatId] : null;
			if (parentServiceInfo) {
				const parts = [parentPlain.Subject, parentServiceInfo.name];
				if (parentServiceInfo.type) parts.push(parentServiceInfo.type);
				parentPlain.subjectDisplay = parts.join(' - ');
			} else if (parentOrderInfo) {
				const parts = [parentPlain.Subject];
				if (parentOrderInfo.orderNumber) parts.push(parentOrderInfo.orderNumber);
				if (parentOrderInfo.guildLabel) parts.push(parentOrderInfo.guildLabel);
				parentPlain.subjectDisplay = parts.join(' - ');
			} else {
				const isFromRelated = parentPlain.WhatId && parentPlain.WhatId !== this.recordId;
				parentPlain.subjectDisplay = isFromRelated && parentPlain.relatedLabel
					? parentPlain.Subject + ' - ' + parentPlain.relatedLabel
					: (parentPlain.Subject || '');
			}
			const completedTerms = ['completed','completado','concluido','concluída','feito','done'];
			parentPlain.isCompleted = completedTerms.includes((parentPlain.Status || '').toLowerCase());
			parentPlain.titleClass = parentPlain.isCompleted ? 'titleLinkNoBold completedSubject' : 'titleLinkNoBold';

			const childrenPlain = children.map(c => {
				const cp = JSON.parse(JSON.stringify(c));
				cp.ownerName = cp.Owner ? cp.Owner.Name : '';
                cp.relatedLabel = cp.What ? cp.What.Name : (cp.Who ? cp.Who.Name : (cp.WhatId ? cp.WhatId : (cp.WhoId ? cp.WhoId : '')));
				cp.createdDate = cp.CreatedDate || c.CreatedDate || c['CreatedDate'] || cp.ActivityDate || null;
				cp.displayDate = cp.createdDate || cp.ActivityDate || null;
				cp.themeLabel = cp.Theme__c || '';
				cp.subthemeLabel = cp.SubTheme__c || '';
				cp.reminderDateTime = cp.ReminderDateTime || null;
				const cpServiceInfo = cp.WhatId ? this.serviceInfoMap[cp.WhatId] : null;
				const cpOrderInfo = cp.WhatId ? this.orderInfoMap[cp.WhatId] : null;
				if (cpServiceInfo) {
					const parts = [cp.Subject, cpServiceInfo.name];
					if (cpServiceInfo.type) parts.push(cpServiceInfo.type);
					cp.subjectDisplay = parts.join(' - ');
				} else if (cpOrderInfo) {
					const parts = [cp.Subject];
					if (cpOrderInfo.orderNumber) parts.push(cpOrderInfo.orderNumber);
					if (cpOrderInfo.guildLabel) parts.push(cpOrderInfo.guildLabel);
					cp.subjectDisplay = parts.join(' - ');
				} else {
					const cpFromRelated = cp.WhatId && cp.WhatId !== this.recordId;
					cp.subjectDisplay = cpFromRelated && cp.relatedLabel
						? cp.Subject + ' - ' + cp.relatedLabel
						: (cp.Subject || '');
				}
				cp.isCompleted = completedTerms.includes((cp.Status || '').toLowerCase());
				cp.titleClass = cp.isCompleted ? 'titleLinkNoBold completedSubject' : 'titleLinkNoBold';
				return cp;
			});
			const group = {
				id: parentPlain.Id,
				parent: parentPlain,
				children: childrenPlain,
				hasChildren: childrenPlain.length > 0
			};
			console.log('parent CreatedDate raw:', parentPlain.CreatedDate, 'parent.createdDate:', parentPlain.createdDate, 'parent.displayDate:', parentPlain.displayDate, 'type:', typeof parentPlain.createdDate);
			childrenPlain.forEach((c, i) => console.log('child['+i+'] CreatedDate raw:', c.CreatedDate, 'child.createdDate:', c.createdDate, 'child.displayDate:', c.displayDate));
			// Debug: show original parent props access
			console.log('parent direct access parent.CreatedDate:', parent.CreatedDate, "parent['CreatedDate']:", parent['CreatedDate']);
			console.log('Built group:', group.id, 'childrenCount=', childrenPlain.length, 'children=', childrenPlain);
			return group;
		});
		console.log('Task groups:', this.taskGroups);
	}

    toggleExpand(event) {
        const taskId = event.currentTarget.dataset.id;
        if (!taskId) {
            return;
        }
        if (this.expandedTaskIds.includes(taskId)) {
            this.expandedTaskIds = this.expandedTaskIds.filter(id => id !== taskId);
            console.log('collapse taskId=' + taskId);
        } else {
            this.expandedTaskIds = [...this.expandedTaskIds, taskId];
            console.log('expand taskId=' + taskId);
            const group = this.taskGroups.find(g => g.id === taskId);
            console.log('group children count=', group ? group.children.length : 'group not found', 'children=', group ? JSON.stringify(group.children) : '');
        }
    }

    handleSearchChange(event) {
        // Support different event shapes (oninput/onchange and lightning input detail)
        const value = (event && event.target && event.target.value) || (event && event.detail && event.detail.value) || '';
        console.log('handleSearchChange event value:', value);
        this.searchTerm = value ? value.trim().toLowerCase() : '';
        console.log('Search term changed to:', this.searchTerm, 'filtered groups:', (this.taskGroupsView || []).length);
    }

    async refreshTasks() {
        this.loading = true;
        if (this.tasksResult) {
            try {
                await refreshApex(this.tasksResult);
            } catch (e) {
                this.error = e;
            }
        }
        this.loading = false;
    }

    openCreateModal() {
        // initialize fields and open modal
        this.newTaskSubject = '';
        this.newTaskActivityDate = '';
        // Force Assigned To to current user executing the action
        this.newTaskOwnerId = USER_ID;
        // label will be filled by @wire when it runs; fallback text until then
        this.newTaskOwnerLabel = this.newTaskOwnerLabel || '';
        this.newTaskWhoId = '';
        this.newTaskWhatId = this.recordId || '';
        this.newTaskWhatLabel = '';
        this.newTaskWhatLocked = false;
        this.newTaskError = '';

        // reset subject suggestions state
        this.selectedSubject = null;
        this.subjectSuggestions = [];
        this.showSubjectSuggestions = false;
        this.subjectNoResults = false;
        this.subjectHighlightedIndex = -1;
        if (this.subjectDebounceTimer) {
            clearTimeout(this.subjectDebounceTimer);
            this.subjectDebounceTimer = null;
        }
        // If we have a surrounding record, fetch info to decide lock behavior
        if (this.recordId) {
            getRecordInfo({ recordId: this.recordId })
                .then(res => {
                    this.newTaskWhatLabel = res && res.label ? res.label : (this.recordId + '');
                    this.newTaskWhatId = this.recordId;
                    this.newTaskWhatLocked = (res && (res.objectType === 'Case' || res.objectType === 'Order'));
                })
                .catch(err => {
                    console.error('Error fetching record info:', err);
                    this.newTaskWhatLabel = this.recordId + '';
                    this.newTaskWhatId = this.recordId;
                    this.newTaskWhatLocked = false;
                });
        }

        // Ensure we have at least a placeholder until the wired user name populates
        if (!this.newTaskOwnerLabel) {
            this.newTaskOwnerLabel = 'Current User';
        }
        // Owner is locked to the current user executing this action
        this.newTaskOwnerLocked = true;

        this.showCreateModal = true;
    }

    closeCreateModal() {
        this.showCreateModal = false;
    }

    handleNewInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        switch (field) {
            case 'Subject': this.handleParentSubjectInput(value); break;
            case 'ActivityDate': this.newTaskActivityDate = value; break;
            case 'OwnerId': this.newTaskOwnerId = value; break;
            case 'WhoId': this.newTaskWhoId = value; break;
            case 'WhatId': this.newTaskWhatId = value; break;
            default: break;
        }
    }

    handleParentSubjectInput(event) {
        this.newTaskSubject = event.detail.value;
        this.selectedParent = event.detail.value;
    }

    /*handleSubjectInput(event) {
        const value = (event && event.target && event.target.value) || '';
        console.log('handleSubjectInput value=', value);
        this.handleSubjectInputValue(value);
    }

    handleSubjectInputValue(value) {
        this.newTaskSubject = value;
        this.selectedSubject = null;
        this.selectedParent = null;
        let q = (value || '').trim();
        // If user typed a combined label like "Parent — Child", use only the parent side for searching
        if (q && /[-—–]/.test(q)) {
            q = q.split(/[-—–]/)[0].trim();
        }
        console.log('handleSubjectInputValue q=', q);
        if (this.subjectDebounceTimer) {
            clearTimeout(this.subjectDebounceTimer);
            this.subjectDebounceTimer = null;
            console.log('cleared previous subject debounce timer');
        }
        if (!q) {
            this.subjectSuggestions = [];
            this.showSubjectSuggestions = false;
            this.subjectNoResults = false;
            console.log('empty query, cleared suggestions');
            return;
        }
        console.log('scheduling fetchSubjectSuggestions for q=', q);
        this.subjectDebounceTimer = setTimeout(() => {
            this.fetchSubjectSuggestions(q);
        }, 300);
    }*/

    /*async fetchSubjectSuggestions(q) {
        this.subjectLoading = true;
        this.subjectNoResults = false;
        console.log('fetchSubjectSuggestions calling Apex, q=', q, 'recordId=', this.recordId);
        this.lastSubjectQuery = q;
        this.lastSubjectResponseCount = 0;
        this.lastSubjectError = '';
        try {
            const res = await getSubjectSuggestions({ q: q, recordId: this.recordId || null });
            console.log('raw Apex response:', res);
            // res now contains objects { child, parent, label, masterLabel }
            let arr = (res || []).map(s => ({ label: s.label || s.child, value: s.child, parent: s.parent, masterLabel: s.masterLabel, isHighlighted: false }));
            // Deduplicate by parent since UI should only show parents
            const byParent = new Map();
            arr.forEach(s => {
                const pk = (s.parent || s.label || '').trim();
                if (!byParent.has(pk)) {
                    byParent.set(pk, s);
                }
            });
            arr = Array.from(byParent.values());
            console.log('Subject suggestions fetched (mapped, dedup by parent):', arr);
            this.subjectSuggestions = arr;
            this.showSubjectSuggestions = (arr && arr.length > 0);
            this.subjectNoResults = !this.showSubjectSuggestions;
            this.subjectHighlightedIndex = -1;
            this.lastSubjectResponseCount = arr.length;
        } catch (e) {
            console.error('Error fetching subject suggestions', e);
            try {
                console.error('Apex error body:', e && e.body ? JSON.stringify(e.body) : e);
                this.lastSubjectError = e && e.body && e.body.message ? e.body.message : String(e);
            } catch (err) {
                console.error('Error serializing apex error body', err);
                this.lastSubjectError = String(e);
            }
            this.subjectSuggestions = [];
            this.showSubjectSuggestions = false;
            this.subjectNoResults = false;
        } finally {
            this.subjectLoading = false;
        }
    }

    handleSelectSuggestion(event) {
        const val = event.currentTarget && event.currentTarget.dataset && event.currentTarget.dataset.value;
        if (!val) return;
        const s = (this.subjectSuggestions || []).find(x => x.value === val);
        if (s) this.selectSuggestion(s);
    }

    selectSuggestion(valOrObj) {
        let val = null;
        let display = null;
        let parent = null;
        if (valOrObj && typeof valOrObj === 'object') {
            val = valOrObj.value;
            display = valOrObj.parent || valOrObj.label;
            parent = valOrObj.parent || valOrObj.label || valOrObj.value;
        } else {
            val = valOrObj;
            const s = (this.subjectSuggestions || []).find(x => x.value === val);
            display = s ? (s.parent || s.label) : val;
            parent = s ? (s.parent || s.label || s.value) : val;
        }
        this.newTaskSubject = display || (val || '');
        this.selectedSubject = val || null;
        this.selectedParent = parent || null;
        this.showSubjectSuggestions = false;
        this.subjectSuggestions = [];
        this.subjectHighlightedIndex = -1;
    }

    suggestionMouseDown(event) {
        // prevent blur hiding suggestions when clicking
        this.preventSuggestionClose = true;
    }

    handleSubjectKeyDown(event) {
        if (!this.showSubjectSuggestions || !this.subjectSuggestions || this.subjectSuggestions.length === 0) return;
        const key = event.key;
        if (key === 'ArrowDown') {
            event.preventDefault();
            this.subjectHighlightedIndex = Math.min(this.subjectHighlightedIndex + 1, this.subjectSuggestions.length - 1);
            this.updateSubjectHighlightFlags();
            this.scrollHighlightedIntoView();
        } else if (key === 'ArrowUp') {
            event.preventDefault();
            this.subjectHighlightedIndex = Math.max(this.subjectHighlightedIndex - 1, 0);
            this.updateSubjectHighlightFlags();
            this.scrollHighlightedIntoView();
        } else if (key === 'Enter') {
            event.preventDefault();
            if (this.subjectHighlightedIndex >= 0 && this.subjectHighlightedIndex < this.subjectSuggestions.length) {
                const s = this.subjectSuggestions[this.subjectHighlightedIndex];
                if (s) this.selectSuggestion(s);
            }
        } else if (key === 'Escape') {
            this.showSubjectSuggestions = false;
        }
    }

    updateSubjectHighlightFlags() {
        // Set isHighlighted on the correct suggestion object so aria-selected bindings work
        const idx = this.subjectHighlightedIndex;
        this.subjectSuggestions = (this.subjectSuggestions || []).map((s, i) => ({ ...s, isHighlighted: i === idx }));
    }

    handleSubjectFocus() {
        // If user focuses and there is already text, trigger suggestions immediately
        try {
            const q = (this.newTaskSubject || '').trim();
            console.log('handleSubjectFocus q=', q);
            if (q) {
                // directly fetch suggestions without waiting for debounce
                if (this.subjectDebounceTimer) {
                    clearTimeout(this.subjectDebounceTimer);
                    this.subjectDebounceTimer = null;
                }
                this.fetchSubjectSuggestions(q);
            }
        } catch (e) {
            console.error('Error in handleSubjectFocus', e);
        }
    }*/

    /*handleSubjectBlur() {
        setTimeout(() => {
            if (!this.preventSuggestionClose) {
                this.showSubjectSuggestions = false;
            }
            this.preventSuggestionClose = false;
        }, 150);
    }*/

    /*scrollHighlightedIntoView() {
        // use querySelector to find highlighted item and scroll into view
        try {
            const ul = this.template.querySelector('.subject-suggestions');
            if (!ul) return;
            const li = ul.querySelector('[aria-selected="true"]');
            if (li && li.scrollIntoView) {
                li.scrollIntoView({ block: 'nearest' });
            }
        } catch (e) {}
    }*/

    navigateToRecord(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: id, actionName: 'view' }
        });
    }

    async handleCreateSave() {
        // Basic validation
        if (!this.newTaskSubject || !this.newTaskSubject.trim()) {
            this.newTaskError = 'El campo Asunto es obligatorio';
            return;
        }

        // Enforce selection-only: must have a selectedParent (actual Parent value)
        if (!this.selectedParent) {
            this.newTaskError = 'Por favor seleccione un asunto válido de la lista';
            return;
        }

        const fields = { Subject: this.selectedParent };
        if (this.newTaskActivityDate) fields.ActivityDate = this.newTaskActivityDate;
        if (this.newTaskOwnerId) fields.OwnerId = this.newTaskOwnerId;
        if (this.newTaskWhoId) fields.WhoId = this.newTaskWhoId;
        if (this.newTaskWhatId) fields.WhatId = this.newTaskWhatId;

        this.newTaskError = '';
        try {
            // If user typed a WhatId manually, ensure it's a Case or Order (validate)
            if (this.newTaskWhatId && !this.newTaskWhatLocked) {
                try {
                    const info = await getRecordInfo({ recordId: this.newTaskWhatId });
                    if (!info || (info.objectType !== 'Case' && info.objectType !== 'Order')) {
                        this.newTaskError = 'Relacionado com (WhatId) apenas pode ser um Case ou Order.';
                        return;
                    }
                } catch (e) {
                    this.newTaskError = 'Não foi possível validar o Related record. Use um Case ou Order válido.';
                    return;
                }
            }

            const resultId = await createParentTask({ subject: this.selectedParent, activityDate: this.newTaskActivityDate || null, ownerId: this.newTaskOwnerId || null, whoId: null, whatId: this.newTaskWhatId || null });
            const id = resultId;
            this.showCreateModal = false;
            this.dispatchEvent(new ShowToastEvent({ title: 'Tarea creada', message: 'Tarea creada con id ' + id, variant: 'success' }));
            await this.refreshTasks();
        } catch (error) {
            console.error('Error creating task', error);
            // Apex error structure
            let msg = 'Error al crear la tarea';
            try {
                if (error && error.body && error.body.message) {
                    msg = error.body.message;
                } else if (Array.isArray(error.body)) {
                    msg = error.body.map(e => e.message).join('; ');
                } else if (error && error.message) {
                    msg = error.message;
                }
            } catch (e) {
                console.error('Error parsing apex error', e);
            }
            this.newTaskError = msg;
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
        }
    }

    navigateToTask(event) {
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                actionName: 'view'
            }
        });

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