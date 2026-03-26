Feature: Compliance Remediation (Self-Healing)
  As a Platform Auditor
  I want the system to automatically revoke toxic role combinations
  So that the organization remains in a known good security state

  Scenario: Automatically revoking 'approver' role from a 'trader'
    Given a registered user "trader1" exists with role "trader"
    When the user is assigned the additional role "approver"
    Then the "approver" role should be automatically revoked
    And the remediation should be logged in the Compliance Hub
