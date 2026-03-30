Feature: Invitation Flow Success
    As an invited user
    I want to accept my invitation securely
    So that I can join the Nexus platform.

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
