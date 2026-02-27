Feature: Dynamic Cash Flow Outlook
    As a Head of Treasury
    I want a live 30-day view of my cash gap
    So that I can anticipate and mitigate liquidity shortfalls

    Scenario: Ingested invoice updates cash flow outlook
        Given a baseline cash flow outlook for "EUR"
        And a new SAP invoice is received for "Munich HQ" with:
            | amount   | 50000.00 |
            | currency | EUR      |
            | due_date | +15 days |
        Then the "EUR" cash flow outlook should reflect a projected outflow of "50000.00" on "+15 days"

    Scenario: Market rate change updates forecasted gap
        Given a cash flow outlook for "EUR" with a projected gap of "100000.00"
        When the "EUR/USD" market price changes to "1.1000"
        Then the consolidated "EUR" cash gap should be recalculated using the new "1.1000" rate
