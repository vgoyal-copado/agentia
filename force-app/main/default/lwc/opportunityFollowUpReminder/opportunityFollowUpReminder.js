import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import NEEDS_FOLLOW_UP from '@salesforce/schema/Opportunity.Needs_Follow_Up__c';

export default class OpportunityFollowUpReminder extends LightningElement {
    @api recordId;

    @wire(getRecord, { recordId: '$recordId', fields: [NEEDS_FOLLOW_UP] })
    opportunity;

    get showReminder() {
        return getFieldValue(this.opportunity?.data, NEEDS_FOLLOW_UP) === true;
    }
}
