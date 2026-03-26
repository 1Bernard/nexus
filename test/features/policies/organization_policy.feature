Feature: Organization Policy
  As a Tenant Administrator
  I want to manage organization settings
  So that I can control administrative access

  Scenario: Admins can managed organization
    Given a user with role "org_admin" in the organization
    When I check if the user can "edit" "org_management"
    Then the action should be allowed

  Scenario: System Admins can view organization management
    Given a user with role "system_admin" in the organization
    When I check if the user can "view" "org_management"
    Then the action should be allowed

  Scenario: Traders cannot edit organization management
    Given a user with role "trader" in the organization
    When I check if the user can "edit" "org_management"
    Then the action should be denied

  Scenario: Unauthenticated users are denied
    Given no authenticated user
    When I check if the user can "view" "org_management"
    Then the action should be denied
