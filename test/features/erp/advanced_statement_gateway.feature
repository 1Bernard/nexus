Feature: Advanced Statement Gateway
    As an ERP system
    I want to process large bank statements asynchronously
    So that the treasury reconciliation engine always has the latest data.

    Scenario: A large CSV statement is processed and initiates reconciliation
        Given an organization "Nexus Corp" exists
        And a "100" line CSV statement "statement.csv" is uploaded
        When the gateway processes the statement
        Then "100" statement lines should be projected to the read model
        And "100" matching events should be dispatched to the reconciliation engine

    Scenario: Duplicate statement uploads trigger overlap warnings
        Given an organization "Nexus Corp" exists
        And a statement "duplicate.csv" with row "REF001,100.00,USD,Test" has been processed
        When a new statement "duplicate.csv" with row "REF002,200.00,USD,Test" is uploaded
        Then the new statement should have an "overlap_warning" flag set

    Scenario: Reconciliation increments the statement matched count
        Given an organization "Nexus Corp" exists
        And a statement "recon.csv" with 1 line has been processed
        When the transaction for that statement line is reconciled
        Then the statement "matched_count" should be "1"
