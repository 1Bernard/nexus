Feature: User Session Management
  As a registered user
  I want my sessions to be tracked and managed
  So that I can maintain security and access control

  Scenario: Starting a new session
    Given a registered user "test@example.com" exists
    When I start a new session with device "Mozilla/5.0"
    Then a new session projection should be created
    And the session should be marked as active

  Scenario: Expiring an active session
    Given a registered user "test@example.com" exists
    And an active session exists for the user
    When the session is expired
    Then the session projection should be updated
    And the session should be marked as expired
