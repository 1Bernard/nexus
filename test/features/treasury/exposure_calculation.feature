Feature: Treasury Exposure Calculation
    As a treasury manager
    I want the system to calculate my FX risk exposure
    So that I can see how currency fluctuations impact open invoices

    Scenario: Calculating exposure for unhedged invoices
        Given a subsidiary "Munich HQ" has an open "USD" invoice for "100000"
        And the current "EUR/USD" exchange rate is "1.0842"
        When the exposure calculation is triggered
        Then the total exposure for "Munich HQ" is registered as "92233.91" "EUR"

    Scenario: Re-evaluating exposure after a market tick
        Given an existing exposure calculation of "92233.91" "EUR" for "Munich HQ"
        When a new market tick for "EUR/USD" arrives at price "1.1000"
        Then the exposure for "Munich HQ" is recalculated to "90909.09" "EUR"
