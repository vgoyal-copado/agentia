public with sharing class AccountHealthSummaryController {
  @AuraEnabled(cacheable=true)
  public static Integer getEscalatedCaseCount(Id accountId) {
    if (accountId == null) {
      return 0;
    }

    return [
      SELECT COUNT()
      FROM Case
      WHERE AccountId = :accountId AND IsClosed = FALSE AND Priority = 'High'
    ];
  }
}
