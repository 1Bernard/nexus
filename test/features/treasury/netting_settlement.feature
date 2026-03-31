Feature: Netting Settlement Orchestration
    As a Treasury Manager
    I want to settle a netting cycle
    So that intercompany positions are resolved via automated transfers.

    @no_sandbox
    Scenario: Successfully settle an active netting cycle
        Given an active netting cycle exists for "EUR"
        And the following invoices are added to the cycle:
            | subsidiary | amount |
            | Sub_A      | 1000.0 |
            | Sub_B      | -400.0 |
        When the netting cycle is settled
        Then a transfer of 1000.0 should be requested for "Sub_A"
        And a transfer of -400.0 should be requested for "Sub_B"
        And all included invoices should be marked as "netted"
        And the netting cycle status should be "settled"
