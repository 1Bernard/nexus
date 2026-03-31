@feature
@no_sandbox
Feature: Compliance & Audit Hub (CCM)
  As a Compliance Officer
  I want real-time Continuous Control Monitoring (CCM)
  So that I can detect and remediate policy drifts immediately

  @scenario
  Scenario: Real-time detection of high-risk Segregation of Duties (SoD) violation
    Given a standardized organization with a "Strict" treasury policy
    And a user "Alice" with the "trader" role
    When I assign the "admin" role to "Alice"
    Then a "High" severity "Segregation of Duties" drift should be detected
    And the system should automatically revoke the "admin" role from "Alice"
    And a system notification should be sent to "Alice" for remediation

  @scenario
  Scenario: Real-time detection of treasury policy deviation
    Given a standardized organization with a "Standard" treasury policy
    And the current euro exposure is "healthy"
    When an unauthorized high-value transfer of 2000000.0 "EUR" is detected by AI Sentinel
    Then a "Critical" severity "Unauthorized Movement" drift should be detected in the Compliance Hub
    And the "ComplianceRemediationManager" should trigger a manual audit escalation
