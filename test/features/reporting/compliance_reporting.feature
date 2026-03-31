Feature: Compliance Reporting
    As a compliance officer
    I want to see real-time control metrics
    So that the platform maintains high integrity.

    Scenario: Vault balance sync updates liquidity accuracy metric
        Given the compliance organization "Nexus HQ" exists
        When a vault balance for "1000.00" EUR is synced
        Then a compliance "liquidity_accuracy" metric with score "0.98" should be projected

    Scenario: Proposed reconciliation updates escalation integrity metric
        Given the compliance organization "Nexus HQ" exists
        When a reconciliation for "500.00" EUR with variance "5.00" is proposed
        Then an compliance "escalation_integrity" metric with score "1.0" should be projected

    Scenario: Changing transfer threshold detects policy drift
        Given the compliance organization "Nexus HQ" exists
        And a transfer threshold for "100000.00" EUR is set
        When the transfer threshold for "150000.00" EUR is updated
        Then a compliance "policy_drift" metric with score "1" should be projected
        And a drift score of "0.5000" should be recorded

    Scenario: Assigning toxic roles updates SoD metric
        Given the compliance organization "Nexus HQ" exists
        When a user is assigned both "trader" and "admin" roles
        Then a compliance "sod_cleanliness" metric with score "80" should be projected
