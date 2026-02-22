Feature: Tenant Provisioning
    As a System Administrator
    I want to provision a new Tenant organization
    So that their designated Admin can receive an invitation and register a SecureFlow key

    Scenario: A System Admin provisions a new Tenant
        Given a system administrator "bernard" exists in the root organization
        And the admin dashboard is active
        When the system admin provisions a tenant named "Global Corp" with admin email "elena@global-corp.com"
        Then the "TenantProvisioned" event should be emitted
        And the tenant "Global Corp" should exist in the read model
        And an invitation token for "elena@global-corp.com" with role "admin" should be generated

    Scenario: A normal user attempts to provision a Tenant
        Given a normal user "elena" exists in tenant "Global Corp"
        When user "elena" attempts to provision a tenant named "Rogue Inc"
        Then the command should be rejected with an unauthorized error
