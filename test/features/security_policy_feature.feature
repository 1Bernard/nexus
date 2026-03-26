Feature: Cross-Domain Security Policies
  As a Security Auditor
  I want authorization policies to be strictly enforced
  So that users can only access resources they are permitted to see.

  Scenario: Allowing authenticated users for notifications
    Given an authenticated user with "viewer" role
    When they attempt to view notifications
    Then the action should be allowed

  Scenario: Denying unauthenticated or nil users
    Given an unauthenticated user attempts to view notifications
    Then the action should be denied
