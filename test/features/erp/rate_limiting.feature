Feature: SAP Webhook Rate Limiting
    As a system administrator
    I want to rate limit incoming webhook payloads
    So that runaway external ERP scripts do not overwhelm our ingestion engine

    Scenario: Accept a small burst of webhook payloads
        Given a registered tenant "Munich HQ" exists
        When the ERP system sends 5 invoice payloads within the limit
        Then all 5 payloads should be accepted

    Scenario: Reject excessive webhook payloads
        Given a registered tenant "Munich HQ" exists
        When the ERP system sends 150 invoice payloads rapidly
        Then the system should return a 429 Too Many Requests error
        And the excess payloads should not reach the domain aggregate
