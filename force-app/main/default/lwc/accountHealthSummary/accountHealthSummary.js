import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import getOpenCaseCount from "@salesforce/apex/AccountHealthSummaryController.getOpenCaseCount";
import getClosedCaseCount from "@salesforce/apex/AccountHealthSummaryController.getClosedCaseCount";
import CUSTOMER_TIER_FIELD from "@salesforce/schema/Account.Customer_Tier__c";
import HEALTH_SCORE_FIELD from "@salesforce/schema/Account.Health_Score__c";
import ACCOUNT_NAME_FIELD from "@salesforce/schema/Account.Name";
import ACCOUNT_TYPE_FIELD from "@salesforce/schema/Account.Type";

const ACCOUNT_FIELDS = [
  ACCOUNT_NAME_FIELD,
  CUSTOMER_TIER_FIELD,
  HEALTH_SCORE_FIELD,
  ACCOUNT_TYPE_FIELD
];

const TIER_VARIANTS = {
  Bronze: "base",
  Silver: "inverse",
  Gold: "warning",
  Platinum: "success"
};

const OPEN_CASE_ALERT_THRESHOLD = 3;

export default class AccountHealthSummary extends LightningElement {
  @api recordId;

  openCaseCount;
  closedCaseCount;
  apexError;
  closedCaseError;

  @wire(getRecord, { recordId: "$recordId", fields: ACCOUNT_FIELDS })
  account;

  @wire(getOpenCaseCount, { accountId: "$recordId" })
  wiredOpenCaseCount({ data, error }) {
    if (data !== undefined) {
      this.openCaseCount = data;
      this.apexError = undefined;
    } else if (error) {
      this.openCaseCount = undefined;
      this.apexError = error;
    }
  }

  @wire(getClosedCaseCount, { accountId: "$recordId" })
  wiredClosedCaseCount({ data, error }) {
    if (data !== undefined) {
      this.closedCaseCount = data;
      this.closedCaseError = undefined;
    } else if (error) {
      this.closedCaseCount = undefined;
      this.closedCaseError = error;
    }
  }

  get accountName() {
    return getFieldValue(this.account.data, ACCOUNT_NAME_FIELD) || "Account";
  }

  get accountType() {
    return getFieldValue(this.account.data, ACCOUNT_TYPE_FIELD);
  }

  get accountTypeLabel() {
    return this.accountType || "Not set";
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

  get hasOpenCaseCount() {
    return this.openCaseCount !== undefined && !this.apexError;
  }

  get openCaseLabel() {
    if (!this.hasOpenCaseCount) {
      return "—";
    }
    return this.openCaseCount === 1
      ? "1 open case"
      : `${this.openCaseCount} open cases`;
  }

  get showOpenCaseAlert() {
    return (
      this.hasOpenCaseCount && this.openCaseCount > OPEN_CASE_ALERT_THRESHOLD
    );
  }

  get hasClosedCaseCount() {
    return this.closedCaseCount !== undefined && !this.closedCaseError;
  }

  get closedCaseLabel() {
    if (!this.hasClosedCaseCount) {
      return "—";
    }
    return this.closedCaseCount === 1
      ? "1 closed case"
      : `${this.closedCaseCount} closed cases`;
  }

  get isLoading() {
    return !this.account.data && !this.account.error;
  }

  get hasError() {
    return Boolean(
      this.account.error || this.apexError || this.closedCaseError
    );
  }

  get errorMessage() {
    if (this.account.error) {
      return this.account.error.body?.message || "Unable to load account.";
    }
    if (this.apexError) {
      return this.apexError.body?.message || "Unable to load open case count.";
    }
    if (this.closedCaseError) {
      return (
        this.closedCaseError.body?.message ||
        "Unable to load closed case count."
      );
    }
    return "";
  }
}
