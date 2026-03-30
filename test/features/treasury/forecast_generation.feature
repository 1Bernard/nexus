Feature: Treasury Forecast Generation
    As a Treasury Risk Manager
    I want to generate liquidity forecasts from historical data
    So that I can anticipate future cash flow needs.

    Scenario: Generating a forecast from historical statement data
        Given a treasury department with 60 days of historical statement data in "EUR"
        When I request a liquidity forecast for the next 30 days
        And the forecast event is projected into the read model
        Then I should see a 30-day forecast snapshot in the read model
        And the predicted amounts should reflect a consistent trend
