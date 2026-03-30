Feature: Cash Flow Outlook
    As a Treasury Analyst
    I want to see the projected cash flow outlook
    So that I can identify potential liquidity gaps.

    Scenario: A baseline cash flow outlook is generated
        Given a baseline cash flow outlook for "EUR"
        Then the "EUR" cash flow outlook should reflect a projected outflow of "0.00" on "2026-03-03"

    Scenario: Market price changes affect the cash flow outlook
        Given a cash flow outlook for "USD" with a projected gap of "-5000.00"
        When the "EUR/USD" market price changes to "1.10"
        Then the consolidated "EUR" cash gap should be recalculated using the new "1.10" rate
