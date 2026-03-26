Feature: Automated Reconciliation
  As a Treasury Accountant
  I want the system to automatically reconcile matching invoices and bank statements
  So that I can maintain an accurate financial ledger without manual effort

  Scenario: Automatically reconciles an invoice when a matching statement is uploaded
    Given a registered tenant exists
    And an invoice "SAP-101" for "1500.00 EUR" has been ingested
    When a bank statement is uploaded with a reference "BANK-REF-101" for "-1500.00 EUR"
    Then the invoice "SAP-101" should be automatically matched
    And a reconciliation record should exist with status "matched"

  Scenario: Automatically reconciles a statement line when a matching invoice is ingested
    Given a registered tenant exists
    And a bank statement is uploaded with a reference "BANK-REF-202" for "-2400.00 USD"
    When an invoice "SAP-202" for "2400.00 USD" is ingested
    Then the statement reference "BANK-REF-202" should be automatically matched
    And a reconciliation record should exist with status "matched"
