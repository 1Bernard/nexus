Feature: Identity Policy
  As a Security Administrator
  I want to enforce RBAC rules
  So that only authorized users can access sensitive modules

  Scenario: System Admin can access backoffice
    Given a user with role "system_admin"
    When I check if the user can "access" "backoffice"
    Then the action should be allowed

  Scenario: Org Admin cannot access backoffice
    Given a user with role "org_admin"
    When I check if the user can "access" "backoffice"
    Then the action should be denied
