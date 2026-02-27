Feature: Exposure Policy Enforcement
    As a Treasury Risk Manager
    I want the system to monitor exposure against thresholds
    So that I am alerted when risk limits are breached

    Scenario: Exposure exceeds policy threshold
        Given the organization "Nexus Corp" has a transfer threshold of "100000"
        And there is an existing invoice for "Munich HQ" of "120000" EUR
        When the system calculates the "EUR/USD" exposure
        Then a policy alert should be triggered for "Nexus Corp"
        And the alert should suggest an immediate hedge

    Scenario: Exposure is within policy threshold
        Given the organization "Nexus Corp" has a transfer threshold of "200000"
        And there is an existing invoice for "Munich HQ" of "50000" EUR
        When the system calculates the "EUR/USD" exposure
        Then no policy alert should be triggered
