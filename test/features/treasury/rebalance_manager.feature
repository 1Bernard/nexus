Feature: Rebalance Manager
  As the Treasury Sentinel
  I want to monitor cash forecasts
  So that I can automatically request transfers to cover deficits

  Scenario: Automatically request transfer on forecast deficit
    Given a forecast is generated for "USD" with a deficit of "10000.00"
    When the Rebalance Manager handles the forecast
    Then a "RequestTransfer" command should be dispatched for "10000.00" USD from "EUR"

  Scenario: Do not request transfer on forecast surplus
    Given a forecast is generated for "USD" with a surplus of "5000.00"
    When the Rebalance Manager handles the forecast
    Then no "RequestTransfer" command should be dispatched
