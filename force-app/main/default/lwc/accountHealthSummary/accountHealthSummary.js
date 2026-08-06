import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import getEscalatedCaseCount from "@salesforce/apex/AccountHealthSummaryController.getEscalatedCaseCount";
import CUSTOMER_TIER_FIELD from "@salesforce/schema/Account.Customer_Tier__c";
import HEALTH_SCORE_FIELD from "@salesforce/schema/Account.Health_Score__c";
import ACCOUNT_NAME_FIELD from "@salesforce/schema/Account.Name";

const ACCOUNT_FIELDS = [
  ACCOUNT_NAME_FIELD,
  CUSTOMER_TIER_FIELD,
  HEALTH_SCORE_FIELD
];

const TIER_VARIANTS = {
  Bronze: "base",
  Silver: "inverse",
  Gold: "warning",
  Platinum: "success"
};

export default class AccountHealthSummary extends LightningElement {
  @api recordId;

  escalatedCaseCount;
  apexError;

  @wire(getRecord, { recordId: "$recordId", fields: ACCOUNT_FIELDS })
  account;

  @wire(getEscalatedCaseCount, { accountId: "$recordId" })
  wiredEscalatedCaseCount({ data, error }) {
    if (data !== undefined) {
      this.escalatedCaseCount = data;
      this.apexError = undefined;
    } else if (error) {
      this.escalatedCaseCount = undefined;
      this.apexError = error;
    }
  }

  get accountName() {
    return getFieldValue(this.account.data, ACCOUNT_NAME_FIELD) || "Account";
  }

  get customerTier() {
    return getFieldValue(this.account.data, CUSTOMER_TIER_FIELD);
  }

  get healthScore() {
    const score = getFieldValue(this.account.data, HEALTH_SCORE_FIELD);
    return score === null || score === undefined ? null : Number(score);
  }

  get hasTier() {
    return Boolean(this.customerTier);
  }

  get tierVariant() {
    return TIER_VARIANTS[this.customerTier] || "base";
  }

  get hasHealthScore() {
    return this.healthScore !== null;
  }

  get healthScoreLabel() {
    return this.hasHealthScore ? `${this.healthScore}%` : "Not set";
  }

  get healthVariant() {
    if (!this.hasHealthScore) {
      return "base";
    }
    if (this.healthScore >= 80) {
      return "success";
    }
    if (this.healthScore >= 50) {
      return "warning";
    }
    return "error";
  }

  get hasEscalatedCaseCount() {
    return this.escalatedCaseCount !== undefined && !this.apexError;
  }

  get escalatedCaseLabel() {
    if (!this.hasEscalatedCaseCount) {
      return "—";
    }
    if (this.escalatedCaseCount === 0) {
      return "No escalated cases";
    }
    return this.escalatedCaseCount === 1
      ? "1 escalated case"
      : `${this.escalatedCaseCount} escalated cases`;
  }

  get showEscalationWarning() {
    return this.hasEscalatedCaseCount && this.escalatedCaseCount > 0;
  }

  get isLoading() {
    return !this.account.data && !this.account.error;
  }

  get hasError() {
    return Boolean(this.account.error || this.apexError);
  }

  get errorMessage() {
    if (this.account.error) {
      return this.account.error.body?.message || "Unable to load account.";
    }
    if (this.apexError) {
      return (
        this.apexError.body?.message || "Unable to load escalated case count."
      );
    }
    return "";
  }
}
