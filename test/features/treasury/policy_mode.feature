Feature: Policy Mode Persistence
    As a Head of Treasury
    I want to select a named risk tolerance mode (Standard, Strict, Relaxed)
    So that my preferred exposure threshold is saved and enforced consistently across sessions

    Scenario: Treasury manager selects Strict mode and it persists across page reloads
        Given the organization "Nexus Corp" has no policy mode set
        When the treasury manager selects "strict" mode
        Then the policy mode should be saved as "strict"
        And the transfer threshold should be "50000"

    Scenario: Switching from Strict to Relaxed emits an audit event
        Given the organization "Nexus Corp" is on "strict" mode
        When the treasury manager switches to "relaxed" mode
        Then the policy mode should be saved as "relaxed"
        And the transfer threshold should be "10000000"

    Scenario: Policy alerts use the persisted mode threshold, not a hardcoded default
        Given the organization "Nexus Corp" is on "strict" mode
        And the strict mode threshold is "50000"
        When the system evaluates an exposure of "60000" EUR/USD
        Then a policy alert should be triggered
