Feature: Exposure Calculation
    As a treasury system
    I want to calculate currency exposure from invoices and statements
    So that I can identify liquidity risks.

    Scenario: Calculating exposure for unhedged invoices
        Given a subsidiary "Berlin HQ" has an open "EUR" invoice for "50000.00"
        And the current "EUR/USD" exchange rate is "1.0850"
        When the exposure calculation is triggered
        Then the total exposure for "Berlin HQ" is registered as "46082.95" "EUR"

    Scenario: Re-evaluating exposure after a market tick
        Given an existing exposure calculation of "50000.00" "EUR" for "Berlin HQ"
        When a new market tick for "EUR/USD" arrives at price "1.1000"
        Then the exposure for "Berlin HQ" is recalculated to "90909.09" "EUR"
