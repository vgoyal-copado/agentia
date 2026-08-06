@IsTest
private class CaseEscalationSummaryControllerTest {
  @IsTest
  static void getEscalationStatus_returnsFalseWhenNotEscalated() {
    Case caseRecord = new Case(
      Subject = 'Escalation Summary Test Case',
      Status = 'New',
      Needs_Escalation__c = false
    );
    insert caseRecord;

    Test.startTest();
    Boolean needsEscalation = CaseEscalationSummaryController.getEscalationStatus(
      caseRecord.Id
    );
    Test.stopTest();

    System.assertEquals(
      false,
      needsEscalation,
      'Expected no escalation when Needs_Escalation__c is false'
    );
  }

  @IsTest
  static void getEscalationStatus_returnsTrueWhenEscalated() {
    Case caseRecord = new Case(
      Subject = 'Escalated Summary Test Case',
      Status = 'New',
      Needs_Escalation__c = true
    );
    insert caseRecord;

    Test.startTest();
    Boolean needsEscalation = CaseEscalationSummaryController.getEscalationStatus(
      caseRecord.Id
    );
    Test.stopTest();

    System.assertEquals(
      true,
      needsEscalation,
      'Expected escalation when Needs_Escalation__c is true'
    );
  }

  @IsTest
  static void getEscalationStatus_returnsFalseForNullCaseId() {
    Test.startTest();
    Boolean needsEscalation = CaseEscalationSummaryController.getEscalationStatus(
      null
    );
    Test.stopTest();

    System.assertEquals(
      false,
      needsEscalation,
      'Expected false for null case Id'
    );
  }
}
