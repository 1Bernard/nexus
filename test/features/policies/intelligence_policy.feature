Feature: Intelligence Policy
  As a Compliance Officer
  I want to access intelligence reports
  So that I can verify regulatory compliance

  Scenario: Auditors can access compliance
    Given a user with role "auditor" in the intelligence context
    When I check if the user can "view" "compliance"
    Then the action should be allowed

  Scenario: System Admins can access compliance
    Given a user with role "system_admin" in the intelligence context
    When I check if the user can "view" "compliance"
    Then the action should be allowed

  Scenario: Traders cannot access compliance
    Given a user with role "trader" in the intelligence context
    When I check if the user can "view" "compliance"
    Then the action should be denied

  Scenario: Unauthenticated users are denied
    Given no authenticated user in the intelligence context
    When I check if the user can "view" "compliance"
    Then the action should be denied
