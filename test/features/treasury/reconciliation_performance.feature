Feature: Reconciliation Performance
    As a treasury system
    I want to match invoices with statement lines in constant time
    So that the system remains responsive under heavy transaction load.

    Scenario: Match engine performs O(1) lookup under load
        Given the match engine is seeded with "1000" invoices
        And a statement with a line for "-9999.99" exists
        When a new invoice for "9999.99" is ingested
        Then the invoice should be matched in sub-millisecond time
        And a reconciliation command should be dispatched
