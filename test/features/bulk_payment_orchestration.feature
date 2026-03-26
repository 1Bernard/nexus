Feature: Bulk Payment Orchestration
  As a Payment Processor
  I want to orchestrate bulk payment batches into individual transfers
  So that I can process large volumes of payments efficiently with full auditability.

  Scenario: Orchestrating a bulk payment with multiple items
    Given a bulk payment batch "batch-1" is initiated with segments "EUR" and "USD"
    When the saga processes the initiSc
    ation event
    Then it should dispatch "2" individual transfer requests
    And each request should follow the original payment details

  Scenario: Finalizing a bulk payment batch
    Given a bulk payment saga for "batch-1" has "1" remaining item out of "2"
    When a transfer is initiated for the final item
    Then the saga should dispatch a finalization command for the batch

  Scenario: Matching invoices during bulk payment initiation
    Given a bulk payment batch "batch-1" includes an item for invoice "inv-99"
    When the saga processes the initiation event
    Then it should dispatch both a transfer request and an invoice matching command
