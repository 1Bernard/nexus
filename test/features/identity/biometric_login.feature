Feature: Biometric Dashboard Login
    As a Treasury User
    I want to log into the Nexus dashboard using my hardware security key
    So that I am protected from phishing and credential theft

    Scenario: Successful password-less login
        Given the "Identity" domain is active
        And the user "Elena V." has a registered "Yubikey" under "Global Corp" with role "trader"
        When Elena attempts to authenticate with her hardware security key
        Then the system should generate a "WebAuthn Challenge"
        And store it in the "AuthChallengeStore" for 60 seconds
        When Elena performs a fingerprint scan on her hardware device
        Then the system should verify the signature using the "Wax" library
        And the "Identity" aggregate should emit a "SessionStarted" event
        And Elena should be redirected to the "Exposure Monitor" dashboard

    Scenario: Handling expired challenges during login
        Given the "Identity" domain is active
        And the user "Elena V." has a registered "Yubikey" under "Global Corp" with role "trader"
        And a login challenge was generated 65 seconds ago
        When Elena attempts to complete the biometric handshake
        Then the system should return an "Authentication Expired" error
        And the user should be prompted to "Retry Handshake"