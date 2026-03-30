Feature: Invitation Flow
    As an invited user
    I want to accept my invitation securely
    So that I can join the Nexus platform.

    Scenario: User attempts to use an invalid invitation link
        Given an invalid invitation "bad-token-123"
        When they navigate to it
        Then they should see "Invalid or Expired Link"
        And they should see "This invitation link is no longer valid"

    Scenario: User accepts a valid invitation link
        Given a valid invitation exists for "trader" role
        When they use a valid invitation
        Then they should see "Accept Invitation"
        And they should see "trader" in the role description
        When they submit the acceptance form with values:
            | display_name      | email                   |
            | Test Invited User | test.invitee@global.com |
        Then they should be redirected to the identity gate
        And the gate token should contain the correct invitation data
