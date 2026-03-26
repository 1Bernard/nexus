Feature: Biometric Login
  As a User with Biometric Enrollment
  I want to securely log in using WebAuthn
  So that I can access my account without a password.

  Scenario: Successful biometric login
    Given an enrolled user "owusu-ansah@nexus.ai" exists
    When they initiate a biometric login challenge
    And they provide a valid WebAuthn assertion
    Then the login should be successful
    And a session should be established

  Scenario: Failed biometric login with invalid assertion
    Given an enrolled user "owusu-ansah@nexus.ai" exists
    When they initiate a biometric login challenge
    And they provide an invalid WebAuthn assertion
    Then the login should be rejected
    And no session should be established