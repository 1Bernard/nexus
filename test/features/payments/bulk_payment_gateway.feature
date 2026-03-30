Feature: Bulk Payment Gateway
    As a treasury administrator
    I want to upload and authorize bulk payment batches
    So that I can process institutional payments efficiently.

    Scenario: User uploads a CSV and reviews staged payments
        Given an organization admin is logged in
        When they navigate to the payment gateway
        And they upload a CSV batch with content:
            """
            150.00,EUR,Vendor A,ACCOUNT-A-123
            500.50,GBP,Vendor B,ACCOUNT-B-456
            """
        Then they should see "Vendor A" for "150.00"
        And they should see "Vendor B" for "500.50"

    Scenario: User authorizes a staged batch
        Given an organization admin is logged in
        When they navigate to the payment gateway
        And they upload a CSV batch with content:
            """
            100.00,EUR,Target Vendor,IBAN12345678
            """
        And they authorize and instate the batch
        Then they should see "Institutional Payment Batch Initiated"
        And the review modal should be closed
