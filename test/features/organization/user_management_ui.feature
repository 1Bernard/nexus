Feature: User Management UI
    As an organization administrator
    I want to manage users through a secure interface
    So that I can control access to the Nexus platform.

    Scenario: Admin can view the user list
        Given an organization admin is logged in
        When they navigate to the "Users" page
        Then they should see the user "Test Admin" in the team list
        And the "Invite User" button should be visible

    Scenario: Admin can generate an invitation link
        Given an organization admin is logged in
        When they open the "Invite User" modal
        And they select the "trader" role for the invitation
        Then a "Single-Use Secure Link" should be generated

    Scenario: Admin can filter users by role
        Given an organization admin is logged in
        And a user "Trader Joe" exists with role "trader"
        When they filter the user list by "trader"
        Then they should see the filtered user "Trader Joe" in the list
        And they should not see the admin user
