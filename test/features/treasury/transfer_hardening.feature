Feature: Transfer Hardening
    As a treasury system
    I want to ensure all transfers are immutable and correctly projected
    So that the organization's financial ledger remains auditable and consistent.

    Scenario: Low-value transfers are processed immediately
        Given an authorized user exists for an organization
        When the user requests a transfer for "100.00" EUR below the "1,000,000.00" threshold
        Then the transfer should be "authorized"
        And the transfer should eventually be "executed"

    Scenario: High-value transfers require step-up authorization
        Given an authorized user exists for an organization
        When the user requests a transfer for "5,000,000.00" EUR above the "1,000,000.00" threshold
        Then the transfer should be "pending_authorization"
        When the user verifies their step-up identity
        Then the transfer should be "authorized"
        And the transfer should eventually be "executed"
