Feature: Liquidity Forecasting
  As a Treasury Manager
  I want to generate liquidity forecasts based on historical cash flow data
  So that I can anticipate and mitigate capital shortages

  Scenario: Successfully generating a 30-day "EUR" liquidity forecast
    Given the audit log contains historical data for the last 60 days
    When I request a 30-day "EUR" liquidity forecast for my organization
    Then a new forecast snapshot should be generated with 30 data points
    And the first predicted amount should be within the historical trend range
