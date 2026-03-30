Feature: Treasury Reconciliation
    As a Treasury Analyst
    I want to reconcile transactions
    So that the ledger and bank statement are in sync.

    Scenario: Reconciling multiple invoices with statement lines
        Given the following invoices exist:
            | invoice_id | amount  | currency |
            | INV-1      | 1000.00 | EUR      |
            | INV-2      | 2000.00 | EUR      |
        And the following statement lines exist:
            | statement_line_id | amount  | currency |
            | LINE-1            | 1000.00 | EUR      |
        When the matching engine runs
        Then the invoice "INV-1" and statement line "LINE-1" should be reconciled
        And the process manager should dispatch a ReconcileTransaction command for "INV-1"

    Scenario: Recording settlement unmatched exception
        Given an invoice "INV-3" is ingested for 5000.00 USD
        When a statement line "LINE-2" is uploaded for 3000.00 USD
        Then a settlement unmatched exception should be recorded for "LINE-2"
