Feature: Treasury Forecast Dispatch
  As a Treasury Analyst
  I want to dispatch forecast predictions to the treasury aggregate
  So that the system can maintain an up-to-date liquidity forecast for risk calculation.

  Scenario: Dispatching a valid forecast
    Given a valid forecast request for "EUR" with "30" day horizon
    When the command is dispatched to the Nexus ecosystem
    Then the dispatch should be accepted and recorded as successful
