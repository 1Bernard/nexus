Feature: Payment Lifecycle Orchestration
    As a payment processing system
    I want to orchestrate external payments after internal transfers
    So that funds are settled correctly with external providers.

    Scenario: A transfer execution triggers an external payment initiation
        Given a transfer of "1000.00" USD to "EUR" has been executed
        When the payment execution saga handles the transfer event
        Then an external payment of "1000.00" EUR should be initiated
        And the saga status should be "transfer_executed"

    Scenario: External payment settlement completes the saga
        Given a payment execution saga in status "transfer_executed"
        When the external payment is settled
        Then the saga should be stopped
