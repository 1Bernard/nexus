Feature: Segregation of Duties (SoD) Management
  As a Compliance Officer
  I want the system to automatically identify toxic role combinations
  So that I can maintain audit cleanliness and prevent financial fraud.

  Background:
    Given an organization exists in the Nexus ecosystem

  Scenario: Identifying no conflicts for users with single roles
    When a user is assigned the "trader" role
    And another user is assigned the "approver" role
    And another user is assigned the "admin" role
    Then the SoD conflict report should be empty

  Scenario: Flagging Initiate and Authorize conflict
    Given we assign the "trader" and "approver" roles to a user
    Then an "Initiate + Authorize" conflict should be flagged with "High" severity

  Scenario: Flagging Initiate and Policy conflict
    Given we assign the "trader" and "admin" roles to a user
    Then an "Initiate + Policy" conflict should be flagged with "High" severity
    And an "Initiate + Authorize" conflict should also be flagged

  Scenario: Flagging Authorize and Policy conflict
    Given we assign the "approver" and "admin" roles to a user
    Then an "Authorize + Policy" conflict should be flagged with "Medium" severity

  Scenario: Strict organizational scoping
    When a toxic role combination is assigned to a user in a different organization
    Then the SoD conflict report for the current organization should remain empty
