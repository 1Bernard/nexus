Feature: Portfolio Integration
    As a Treasury Analyst
    I want to analyze my asset portfolio
    So that I can maintain target allocations.

    Scenario: Calculating rebalancing suggestions
        Given a treasury policy with target allocations "USD: 0.6, EUR: 0.4"
        And liquidity positions of "50000" USD and "50000" EUR
        When I calculate the portfolio rebalancing suggestions
        Then the engine should suggest selling "EUR" and buying "USD"

    Scenario: Requesting a portfolio rebalance
        Given a treasury policy exists for the organization
        When I request a portfolio rebalance
        Then a "RebalancePortfolioRequested" event should be emitted
