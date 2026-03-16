Feature: User Settings & Security
  As a treasurer
  I want to manage my account preferences and security sessions
  So that I can maintain institutional control over my workspace

  Scenario: Updating localization preferences
    Given I am a registered user "Bernard"
    And I have an active secure session
    When I select "French" as my language
    And I select "Europe/Paris" as my timezone
    And I click "Save Changes"
    Then I should see "Settings updated successfully"
    And my preferences should be persisted as "fr" and "Europe/Paris"

  Scenario: Monitoring active sessions
    Given I am a registered user "Bernard"
    And I have an active secure session
    And I am on the "Security" tab
    Then I should see "Active Now" next to my current session
    And I should see the device type and last active timestamp
    And I should see an "AES-256 · PASSKEY SECURED" indicator

  Scenario: Revoking a remote session
    Given I am a registered user "Bernard"
    And I have an active secure session
    And I am on the "Security" tab
    And there is an active session from a "Mobile" device
    When I click the "revoke" icon for the mobile session
    Then the session should be terminated
    And I should see "Session revoked successfully"
