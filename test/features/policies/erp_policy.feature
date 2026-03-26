Feature: ERP Policy
  As a security-conscious system
  I want to restrict access to ERP data
  So that only authenticated users can view business processes

  Scenario: Authenticated User Access
    Given an authenticated user in the ERP context
    When I check if the user can "view" "erp"
    Then the action should be "allowed"

  Scenario: Unauthenticated User Access
    Given no authenticated user in the ERP context
    When I check if the user can "view" "erp"
    Then the action should be "denied"
