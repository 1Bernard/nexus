Feature: Treasury Risk Rebalancing
    As a Treasury Risk Manager
    I want to calculate net exposure after transfers
    So that I can reduce the organization's risk variance.

    Scenario: Executing a transfer decreases net exposure
        Given a tenant has a gross exposure of "1,000,000 EUR"
        And the initial risk summary is calculated
        When a transfer of "400,000 EUR" to "USD" is executed
        Then the EUR liquidity position should be "-400,000"
        And the net EUR exposure should be "600,000"
        And the total risk variance should decrease
