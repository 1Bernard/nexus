Feature: Step-Up Authorization
    As a security-conscious organization
    I want to require secondary biometric verification for high-value actions
    So that I can prevent unauthorized transactions even if a session is compromised

    Scenario: Large treasury transfer requires step-up
        Given I am logged in as a "treasury_admin"
        And the currency pair is "EUR/USD"
        When I attempt to initiate a high-value transfer of "5000000"
        Then I should be prompted for step-up biometric verification
        And the transfer should not be recorded yet

    Scenario: Successful step-up allows the action
        Given I am at the step-up verification prompt
        When I provide a valid biometric signature
        Then the transfer should be successfully authorized
        And I should see a success notification
