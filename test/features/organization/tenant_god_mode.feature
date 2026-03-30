Feature: Tenant God-Mode
    As a system administrator
    I want to perform administrative actions on tenants
    So that I can manage the platform's lifecycle and access controls.

    Scenario: A tenant can be suspended and resumed
        Given an active tenant "Nexus Corp" exists
        When the system administrator suspends the tenant for "Policy Violation"
        Then the tenant status should be "SUSPENDED"

    Scenario: Tenant modules can be toggled
        Given an active tenant "Nexus Corp" exists
        When the "forecasting" module is enabled for the tenant
        Then the "forecasting" module should be active in the read model
        When the "forecasting" module is disabled for the tenant
        Then the "forecasting" module should be inactive in the read model
