Feature: Biometric Handshake Verification
    As a high-security user
    I want my biometric fingerprint to be verified against a transient challenge
    So that my identity is cryptographically proven and protected from replay attacks

    Scenario: Successful Biometric Verification
        Given a user "bernard" is registered with a public key under "Nexus Corp" with role "trader"
        And a valid session ID "session_123"
        When the system generates a biometric challenge for "session_123"
        And "bernard" signs the challenge with their hardware sensor
        Then the challenge should be successfully popped from the ETS store
        And the biometric signature should be verified as authentic
        And a "BiometricVerified" event should be emitted
        And the user should be "found in the database" with their public key
