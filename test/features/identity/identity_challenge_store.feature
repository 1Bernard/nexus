Feature: Biometric Challenge Management
    As a Technical Auditor
    I want biometric challenges to be transient and high-performance
    So that we prevent replay attacks without bloating the permanent event ledger

    Scenario: Temporary storage of a WebAuthn challenge
        Given the Identity Challenge Store is "Running"
        And a secure session "session_99" has been established
        When the system generates a challenge "hex_8822_9911" for "session_99"
        Then the challenge should be stored in the in-memory "ETS" cache
        And it should be available for retrieval for "60" seconds

    Scenario: Prevention of Replay Attacks (One-Time Use)
        Given the Identity Challenge Store is "Running"
        And a secure session "session_99" has been established
        And a stored challenge "hex_8822_9911" exists for "session_99"
        When the user retrieves the challenge for verification
        Then the system should return "hex_8822_9911"
        And the challenge should be "immediately deleted" from the cache
        And a second attempt to retrieve the challenge should return "not_found"

    Scenario: Challenge Expiration (TTL)
        Given the Identity Challenge Store is "Running"
        And a secure session "session_99" has been established
        And a stored challenge "expired_token" exists for "session_99"
        And "61" seconds have passed
        When the user attempts to retrieve the challenge
        Then the system should return an "expired" error