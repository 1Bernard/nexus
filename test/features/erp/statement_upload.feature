Feature: Statement Upload
    As a treasury administrator
    I want to upload bank statements in MT940 or CSV format
    So that I can reconcile transactions against open invoices

    Scenario: A valid MT940 statement is uploaded successfully
        Given I am uploading as organisation "org-f8-a"
        When I upload an MT940 statement with 3 transaction lines
        Then the statement should be accepted
        And the statement should have 3 parsed lines

    Scenario: A valid CSV statement is uploaded successfully
        Given I am uploading as organisation "org-f8-b"
        When I upload a CSV statement with 2 transaction lines
        Then the statement should be accepted
        And the statement should have 2 parsed lines

    Scenario: An empty or invalid file is rejected
        Given I am uploading as organisation "org-f8-c"
        When I upload an invalid statement file
        Then the statement should be rejected with a reason
