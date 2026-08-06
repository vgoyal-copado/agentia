public with sharing class CaseEscalationSummaryController {
  @AuraEnabled(cacheable=true)
  public static Boolean getEscalationStatus(Id caseId) {
    if (caseId == null) {
      return false;
    }

    Case caseRecord = [
      SELECT Needs_Escalation__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];

    return caseRecord.Needs_Escalation__c == true;
  }
}
