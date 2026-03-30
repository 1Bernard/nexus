Feature: Compliance Reporting
    As a compliance officer
    I want to see real-time control metrics
    So that the platform maintains high integrity.

    Scenario: Vault balance sync updates liquidity accuracy metric
        Given an organization "Nexus HQ" exists
        When a vault balance for "1000.00" EUR is synced
        Then a "liquidity_accuracy" metric with score "0.98" should be projected

    Scenario: Proposed reconciliation updates escalation integrity metric
        Given an organization "Nexus HQ" exists
        When a reconciliation for "500.00" EUR with variance "5.00" is proposed
        Then an "escalation_integrity" metric with score "1.0" should be projected
