Feature: Policy Mode
    As a system administrator
    I want to toggle between different treasury policy modes
    So that I can adjust the system's risk appetite.

    Scenario: Setting the initial policy mode
        Given the organization "Nexus HQ" has no policy mode set
        When the treasury manager selects "standard" mode
        Then the policy mode should be saved as "standard"
        And the transfer threshold should be "1000000"

    Scenario: Switching to strict mode records audit log
        Given the organization "Nexus HQ" is on "standard" mode
        When the treasury manager switches to "strict" mode
        Then the policy mode should be saved as "strict"
        And an audit log should be recorded for "strict" mode
        And the audit log should attribute the change to "test@example.com"

    Scenario: Strict mode triggers alerts on exposure
        Given the organization "Nexus HQ" is on "strict" mode
        And the strict mode threshold is "50000"
        When the system evaluates an exposure of "75000" EUR/USD
        Then a policy alert should be triggered
