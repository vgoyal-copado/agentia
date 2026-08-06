@IsTest
private class AccountHealthSummaryControllerTest {
  @IsTest
  static void getEscalatedCaseCount_returnsZeroWhenNoCases() {
    Account acct = new Account(Name = 'Escalation Test Account');
    insert acct;

    Test.startTest();
    Integer escalatedCount = AccountHealthSummaryController.getEscalatedCaseCount(
      acct.Id
    );
    Test.stopTest();

    System.assertEquals(0, escalatedCount, 'Expected no escalated cases');
  }

  @IsTest
  static void getEscalatedCaseCount_countsOnlyHighPriorityOpenCases() {
    Account acct = new Account(Name = 'Escalation Case Account');
    insert acct;

    insert new Case(
      Subject = 'High Priority Open',
      Status = 'New',
      Priority = 'High',
      AccountId = acct.Id
    );
    insert new Case(
      Subject = 'Low Priority Open',
      Status = 'New',
      Priority = 'Low',
      AccountId = acct.Id
    );
    insert new Case(
      Subject = 'High Priority Closed',
      Status = 'Closed',
      Priority = 'High',
      AccountId = acct.Id
    );

    Test.startTest();
    Integer escalatedCount = AccountHealthSummaryController.getEscalatedCaseCount(
      acct.Id
    );
    Test.stopTest();

    System.assertEquals(
      1,
      escalatedCount,
      'Expected one high-priority open case'
    );
  }

  @IsTest
  static void getEscalatedCaseCount_returnsZeroForNullAccountId() {
    Test.startTest();
    Integer escalatedCount = AccountHealthSummaryController.getEscalatedCaseCount(
      null
    );
    Test.stopTest();

    System.assertEquals(0, escalatedCount, 'Expected zero for null account');
  }
}
