import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import NEEDS_ESCALATION from '@salesforce/schema/Case.Needs_Escalation__c';

export default class CaseEscalationBanner extends LightningElement {
    @api recordId;

    @wire(getRecord, { recordId: '$recordId', fields: [NEEDS_ESCALATION] })
    caseRecord;

    get showBanner() {
        return getFieldValue(this.caseRecord?.data, NEEDS_ESCALATION) === true;
    }
}
