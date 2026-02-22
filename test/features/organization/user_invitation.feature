Feature: User Invitations
    As a Tenant Administrator
    I want to invite new users to my organization
    So they can register their SecureFlow key and access the platform

    Scenario: A Tenant Admin invites a new trader
        Given a tenant "Stark Industries" exists with id "org-123"
        And an admin user "elena" exists in tenant "org-123"
        And the tenant dashboard is active for "elena"
        When user "elena" invites "marcus@stark.com" with role "trader"
        Then the "UserInvited" event should be emitted
        And an invitation token for "marcus@stark.com" should exist in the read model for "org-123"

    Scenario: A Viewer attempts to invite a user
        Given a tenant "Stark Industries" exists with id "org-123"
        And a viewer user "peter" exists in tenant "org-123"
        When user "peter" attempts to invite "ned@stark.com" with role "trader"
        Then the command should be rejected with an unauthorized error

    Scenario: Inviting a user that already exists in the Tenant
        Given a tenant "Stark Industries" exists with id "org-123"
        And an admin user "elena" exists in tenant "org-123"
        And a trader user "marcus@stark.com" already exists in tenant "org-123"
        When user "elena" invites "marcus@stark.com" with role "viewer"
        Then the command should be rejected with an email already registered error
