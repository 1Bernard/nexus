Feature: Auto Rebalance Trigger
    As a treasury system
    I want to trigger rebalances automatically
    So that the organization maintains its target currency positions.

    Scenario: Triggering a rebalance from a deficit forecast
        Given a vault "EUR Operating" with balance "100000.00" exists
        When a forecast for "USD" predicts a deficit of "50000.00"
        Then a Rebalance command should be dispatched for "USD"

    Scenario: No rebalance triggered for a surplus forecast
        Given an active rebalance saga for "USD"
        When a forecast for "USD" predicts a surplus of "10000.00"
        Then no Rebalance command should be dispatched
