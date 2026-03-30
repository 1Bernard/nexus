Feature: Treasury Rebalance Orchestration
    As a treasury system
    I want to orchestrate rebalances based on forecasts
    So that liquidity is maintained across all vaults.

    Scenario: Generating a rebalance command from a deficit forecast
        Given an organization has an active "EUR" vault with "10000.00" balance
        When a forecast reports a deficit of "5000.00" in "USD"
        Then a transfer request from "EUR" to "USD" should be dispatched for "5000.00"
        And the transfer should be attributed to "system-rebalance"
