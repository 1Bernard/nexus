Feature: Institutional Vault Management
  As a Treasury Manager
  I want to manage institutional bank accounts (vaults)
  So that I can monitor real-time liquidity and automate settlements

  Scenario: Registering a new institutional vault
    Given I am logged in as a "treasurer"
    And I am on the "Vault Center" page
    When I click "Register Vault"
    And I enter "J.P. Morgan - Operational" as the vault name
    And I select "J.P. Morgan" as the bank
    And I select "USD" as the currency
    And I enter "US1234567890" as the account number
    And I click "Initiate Onboarding"
    Then I should see "Vault registration initiated successfully"
    And the vault "J.P. Morgan - Operational" should appear in the vault list

  Scenario: Synchronizing vault balance via external provider
    Given I am logged in as a "treasurer"
    And I have a registered vault "Goldman Sachs" in "EUR"
    When the external provider updates the balance to "1,500,000.00"
    Then the vault "Goldman Sachs" should display a balance of "€1,500,000.00"
    And the total "EUR" liquidity should be updated

  Scenario: Autonomous rebalancing between vaults
    Given I am logged in as a "treasurer"
    And I have a "USD" vault with "500,000.00"
    And I have a "EUR" vault with "100,000.00"
    When an autonomous rebalance of "125,000.00" is triggered from "USD" to "EUR"
    Then the "USD" vault balance should decrease by "125,000.00"
    And the "EUR" vault balance should increase by "125,000.00"
    And I should see a new rebalancing activity record
