Feature: Automated Transaction Reconciliation
    As a treasury manager
    I want the system to automatically match ingested invoices with uploaded bank statements
    So that I can maintain an accurate real-time view of reconciled cash flows

    Scenario: Exact amount match between Invoice and Statement Line
        Given the following invoices exist:
            | invoice_id | amount | currency |
            | INV-1001   | 1500.0 | EUR      |
        And the following statement lines exist:
            | statement_line_id | amount | currency |
            | STMT-LINE-A       | 1500.0 | EUR      |
        When the matching engine runs
        Then the invoice "INV-1001" and statement line "STMT-LINE-A" should be reconciled

    Scenario: Statement line without a matching invoice flags as unmatched (Exception)
        Given the following statement lines exist:
            | statement_line_id | amount | currency |
            | STMT-LINE-B       | 999.0  | USD      |
        When the matching engine runs
        Then a settlement unmatched exception should be recorded for "STMT-LINE-B"

    Scenario: Process manager coordinates events across boundaries
        Given an invoice "INV-2000" is ingested for 500.0 GBP
        When a statement line "STMT-LINE-C" is uploaded for 500.0 GBP
        Then the process manager should dispatch a ReconcileTransaction command for "INV-2000"
