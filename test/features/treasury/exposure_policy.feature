Feature: Exposure Policy
    As a Treasury Risk Manager
    I want the system to alert me when currency exposure exceeds thresholds
    So that I can mitigate potential losses.

    Scenario: Exposure exceeds the transfer threshold triggers an alert
        Given the organization "Nexus HQ" has a transfer threshold of "10000.00"
        And there is an existing invoice for "Berlin" of "15000.00" EUR
        When the system calculates the "EUR/USD" exposure
        Then a policy alert should be triggered for "Nexus HQ"
        And the alert should suggest an immediate hedge

    Scenario: Exposure within threshold does not trigger an alert
        Given the organization "Nexus HQ" has a transfer threshold of "20000.00"
        And there is an existing invoice for "Paris" of "15000.00" EUR
        When the system calculates the "EUR/USD" exposure
        Then no policy alert should be triggered
