@IsTest
private class AccountHealthSummaryControllerTest {
  @IsTest
  static void getOpenCaseCount_returnsZeroWhenNoCases() {
    Account acct = new Account(Name = 'Health Summary Test Account');
    insert acct;

    Test.startTest();
    Integer openCaseCount = AccountHealthSummaryController.getOpenCaseCount(
      acct.Id
    );
    Test.stopTest();

    System.assertEquals(0, openCaseCount, 'Expected no open cases');
  }

  @IsTest
  static void getOpenCaseCount_countsOnlyOpenCases() {
    Account acct = new Account(Name = 'Health Summary Case Account');
    insert acct;

    insert new Case(Subject = 'Open Case', Status = 'New', AccountId = acct.Id);
    insert new Case(
      Subject = 'Closed Case',
      Status = 'Closed',
      AccountId = acct.Id
    );

    Test.startTest();
    Integer openCaseCount = AccountHealthSummaryController.getOpenCaseCount(
      acct.Id
    );
    Test.stopTest();

    System.assertEquals(1, openCaseCount, 'Expected one open case');
  }

  @IsTest
  static void getOpenCaseCount_returnsZeroForNullAccountId() {
    Test.startTest();
    Integer openCaseCount = AccountHealthSummaryController.getOpenCaseCount(
      null
    );
    Test.stopTest();

    System.assertEquals(0, openCaseCount, 'Expected zero for null account');
  }
}
