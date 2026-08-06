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
  static void getOpenCaseCount_excludesOnHoldAndClosedCases() {
    Account acct = new Account(Name = 'Health Summary Case Account');
    insert acct;

    insert new Case(Subject = 'Open Case', Status = 'New', AccountId = acct.Id);
    insert new Case(
      Subject = 'On Hold Case',
      Status = 'On Hold',
      AccountId = acct.Id
    );
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

    System.assertEquals(1, openCaseCount, 'Expected one active open case');
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

  @IsTest
  static void getClosedCaseCount_returnsZeroWhenNoCases() {
    Account acct = new Account(Name = 'Closed Case Test Account');
    insert acct;

    Test.startTest();
    Integer closedCaseCount = AccountHealthSummaryController.getClosedCaseCount(
      acct.Id
    );
    Test.stopTest();

    System.assertEquals(0, closedCaseCount, 'Expected no closed cases');
  }

  @IsTest
  static void getClosedCaseCount_countsOnlyClosedCases() {
    Account acct = new Account(Name = 'Closed Case Account');
    insert acct;

    insert new Case(Subject = 'Open Case', Status = 'New', AccountId = acct.Id);
    insert new Case(
      Subject = 'Closed Case',
      Status = 'Closed',
      AccountId = acct.Id
    );

    Test.startTest();
    Integer closedCaseCount = AccountHealthSummaryController.getClosedCaseCount(
      acct.Id
    );
    Test.stopTest();

    System.assertEquals(1, closedCaseCount, 'Expected one closed case');
  }

  @IsTest
  static void getClosedCaseCount_returnsZeroForNullAccountId() {
    Test.startTest();
    Integer closedCaseCount = AccountHealthSummaryController.getClosedCaseCount(
      null
    );
    Test.stopTest();

    System.assertEquals(0, closedCaseCount, 'Expected zero for null account');
  }
}
