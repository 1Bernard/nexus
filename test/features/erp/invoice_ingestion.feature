Feature: Invoice Ingestion Engine
    As an external ERP system
    I want to push invoice data to Nexus
    So that it can be securely ingested into the immutable ledger

    Scenario: Successfully ingest a valid invoice
        Given a registered tenant "Munich HQ" exists
        When the ERP system pushes a valid invoice payload for "1000 EUR"
        Then the invoice should be accepted and recorded
        And an InvoiceIngested event should be emitted

    Scenario: Reject an invoice with a negative amount
        Given a registered tenant "Munich HQ" exists
        When the ERP system pushes an invoice payload with amount "-500 EUR"
        Then the invoice should be rejected
        And an InvoiceRejected event should be emitted

    Scenario: Idempotent handling of duplicate invoices
        Given a registered tenant "Munich HQ" exists
        And an invoice "INV-001" has already been ingested
        When the ERP system pushes the exact same invoice "INV-001" again
        Then the system should gracefully accept the payload without error
        And no duplicate events should be emitted
