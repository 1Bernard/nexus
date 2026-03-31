@feature
Feature: Elite Netting Orchestration
  As a Treasury Manager
  I want to orchestrate multi-currency intercompany netting
  So that I can settle global intercompany debt with high precision and reliability

  @scenario
  Scenario: Multi-currency netting settlement with asynchronous confirmation
    Given a standardized organization with a treasury policy
    And a subsidiary "Sub_A" with an invoice for 1000.0 "EUR"
    And a subsidiary "Sub_B" with an invoice for 500.0 "GBP"
    And the current "GBP/EUR" exchange rate is "1.20"
    When I initialize an elite netting cycle for "EUR" from "2026-03-01" to "2026-03-31"
    And I add the "EUR" invoice to the netting cycle
    And I add the "GBP" invoice to the netting cycle
    And I settle the elite netting cycle
    Then a netting cycle should be in "settling" status
    And a settlement transfer of 1000.0 "EUR" should be requested for "Sub_A"
    And a settlement transfer of 600.0 "EUR" should be requested for "Sub_B"
    When the system confirms the "EUR" transfer for "Sub_A"
    And the system confirms the "EUR" transfer for "Sub_B"
    Then the netting cycle status should be "settled"
    And all included invoices should be marked as "netted"
