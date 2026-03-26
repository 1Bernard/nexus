Feature: Treasury Liquidity Forecasting
  As a treasury manager
  I want to generate liquidity forecasts based on historical statement data
  So that I can proactively manage cash flow and anticipate funding needs

  @no_sandbox
  Scenario: Successfully generating a forecast from historical data
    Given a treasury department with 60 days of historical statement data in "EUR"
    When I request a liquidity forecast for the next 30 days
    And the forecast event is projected into the read model
    Then I should see a 30-day forecast snapshot in the read model
    And the predicted amounts should reflect a consistent trend
