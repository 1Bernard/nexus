Feature: Audit Sampling
  As a Compliance Officer
  I want to generate random and risk-based audit samples
  So that I can verify the integrity of the platform's financial operations

  Scenario: Generating a random audit sample
    Given the audit log contains "5" recorded events
    When I request a "random" sample of size "2"
    Then I should receive "2" events in the sample

  Scenario: Generating a high-value audit sample
    Given the audit log contains events for "EUR" and "USD"
    And some events have an amount greater than "200000"
    When I request a "high_value" sample with threshold "200000"
    Then only events with amount greater than or equal to "200000" should be returned

  Scenario: Generating a risk-based audit sample
    Given the audit log contains "security_step_up_verified" and "tenant_suspended" events
    When I request a "risk_based" sample
    Then the sample should prioritize critical security events
