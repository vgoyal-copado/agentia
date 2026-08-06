public with sharing class AccountHealthSummaryController {
  @AuraEnabled(cacheable=true)
  public static Integer getOpenCaseCount(Id accountId) {
    if (accountId == null) {
      return 0;
    }

    return [
      SELECT COUNT()
      FROM Case
      WHERE AccountId = :accountId AND IsClosed = FALSE AND Status != 'On Hold'
    ];
  }

  @AuraEnabled(cacheable=true)
  public static Integer getClosedCaseCount(Id accountId) {
    if (accountId == null) {
      return 0;
    }

    return [
      SELECT COUNT()
      FROM Case
      WHERE AccountId = :accountId AND IsClosed = TRUE
    ];
  }
}
