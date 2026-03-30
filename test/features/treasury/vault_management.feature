Feature: Vault Management
    As a Treasury Operator
    I want to manage bank accounts and balances
    So that the system accurately reflects our physical holdings.

    Scenario: Registering a new vault
        Given I am logged in as a "TreasuryManager"
        And I am on the "Vault Management" page
        When I enter "HSBC EUR" as the vault name
        And I select "HSBC" as the bank
        And I select "EUR" as the currency
        And I enter "DE12345678" as the account number
        And I click "Initiate Onboarding"
        Then the vault "HSBC EUR" should appear in the vault list

    Scenario: Syncing vault balance from external provider
        Given I have a registered vault "Deutsche Bank" in "EUR"
        When the external provider updates the balance to "12,500.50 €"
        Then the vault "Deutsche Bank" should display a balance of "12,500.50"
        And the total "EUR" liquidity should be updated

    Scenario: Autonomous rebalancing between vaults
        Given I have a "USD" vault with "500,000.00"
        And I have a "EUR" vault with "100,000.00"
        When an autonomous rebalance of "125,000.00" is triggered from "USD" to "EUR"
        Then the "USD" vault balance should decrease by "125,000.00"
        And the "EUR" vault balance should increase by "125,000.00"
        And I should see a new rebalancing activity record
