Feature: Compliance & Audit Hub
    As an Auditor
    I want to monitor system controls and Segregation of Duties in real-time
    So that I can ensure the organization remains compliant and secure

    Scenario: Continuous Control Monitoring indicates system health
        Given the organization "Corporate Ops" has active risk policies
        And no policy bypasses have occurred in the last 24 hours
        When I view the compliance hub
        Then I should see the "Auth Integrity" gauge at "100%"
        And the "Drift Protection" gauge should be "Healthy"

    Scenario: Detecting Segregation of Duties conflicts
        Given a user "trader@corp.com" has the "Trader" role
        And the same user "trader@corp.com" is assigned the "Admin" role
        When I view the Segregation of Duties matrix
        Then I should see a "Toxic Combination" alert for "Initiate + Approve"
        And the user "trader@corp.com" should be listed as a conflict

    Scenario: Verifying Immutable Lineage for a Transfer
        Given a transfer "TRF_123" was initiated and verified via biometric
        When I search for the correlation ID of "TRF_123"
        Then I should see the complete "Chain of Custody" flow
        And every event node should display a "Cryptographically Sealed" status
