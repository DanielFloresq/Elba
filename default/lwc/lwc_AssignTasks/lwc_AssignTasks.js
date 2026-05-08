import { LightningElement, api, track } from 'lwc';
import findRecords from '@salesforce/apex/c_AssignTasks.findRecords';

export default class ReusableLookup extends LightningElement {
    @track recordsList;
    @track searchKey = "";
    @api selectedValue;
    @api selectedRecordId;
    @api objectApiName = 'User';
    @api iconName = 'standard:user';
    @api lookupLabel;
    @api ownerId;
    @track message;

    value = 'User';

    get options() {
        return [
            { label: 'Usuario', value: 'User' },
            { label: 'Cola', value: 'Group' }
        ];
    }

    handleChange(event) {
        this.value = event.detail.value;
        this.searchKey = '';
        this.selectedValue = null;
        if (this.value == 'User') {
            this.objectApiName = 'User';
            this.iconName = 'standard:user';
        } else {
            this.objectApiName = 'Group';
            this.iconName = 'standard:queue';
        }

    }
    onLeave(event) {
        setTimeout(() => {
            this.recordsList = null;
        }, 300);
    }

    onRecordSelection(event) {
        this.selectedRecordId = event.target.dataset.key;
        this.selectedValue = event.target.dataset.name;
        this.searchKey = event.target.dataset.name;
        this.ownerId = this.selectedRecordId;
        console.log(this.selectedRecordId);
    }

    handleKeyChange(event) {
        const searchKey = event.target.value;
        this.searchKey = searchKey;
        console.log(searchKey);
        if (searchKey) {
            this.getLookupResult();
        } else {
            this.selectedValue = null;
        }
    }

    handleSelectedChange(event) {
        const searchKey = event.target.value;
        this.searchKey = searchKey;
        this.selectedValue = null;
    }

    removeRecordOnLookup(event) {
        this.searchKey = "";
        this.selectedValue = null;
        this.selectedRecordId = null;
        this.recordsList = null;
        this.onSeletedRecordUpdate();
    }

    getLookupResult() {
        findRecords({ searchKey: this.searchKey, objectName: this.objectApiName })
            .then((result) => {
                console.log(result);
                if (result.length === 0) {
                    this.recordsList = [];
                    this.message = "No Records Found";
                } else {
                    this.recordsList = result;
                    this.message = "";
                }
                this.error = undefined;
            })
            .catch((error) => {
                this.error = error;
                this.recordsList = undefined;
            });
    }


}