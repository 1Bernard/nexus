Feature: Automated Reconciliation
    As a treasury system
    I want to automatically reconcile bank statements with internal ledger entries
    So that I can identify discrepancies without manual intervention.

    Scenario: Matching statement lines with ledger entries
        Given a registered tenant exists
        And an invoice "INV-101" for "1000.00 EUR" has been ingested
        When a bank statement is uploaded with a reference "INV-101" for "1000.00 EUR"
        Then the invoice "INV-101" should be automatically matched
        And the statement reference "INV-101" should be automatically matched
        And a reconciliation record should exist with status "matched"
