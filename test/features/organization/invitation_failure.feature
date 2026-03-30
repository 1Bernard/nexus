Feature: Invitation Flow Failure
    As an invited user
    I want to be informed if my invitation is invalid.

    Scenario: User attempts to use an invalid invitation link
        Given they navigate with a bad token
        Then they should see "Invalid or Expired Link"
        And they should see "This invitation link is no longer valid"
