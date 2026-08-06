import { LightningElement, api, wire } from "lwc";
import getEscalationStatus from "@salesforce/apex/CaseEscalationSummaryController.getEscalationStatus";

export default class CaseEscalationSummary extends LightningElement {
  @api recordId;

  needsEscalation;
  apexError;

  @wire(getEscalationStatus, { caseId: "$recordId" })
  wiredEscalationStatus({ data, error }) {
    if (data !== undefined) {
      this.needsEscalation = data;
      this.apexError = undefined;
    } else if (error) {
      this.needsEscalation = undefined;
      this.apexError = error;
    }
  }

  get isLoading() {
    return this.needsEscalation === undefined && !this.apexError;
  }

  get hasError() {
    return Boolean(this.apexError);
  }

  get errorMessage() {
    return this.apexError?.body?.message || "Unable to load escalation status.";
  }

  get showWarningBanner() {
    return this.needsEscalation === true;
  }

  get showEmptyState() {
    return this.needsEscalation === false;
  }
}
