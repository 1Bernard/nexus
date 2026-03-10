Feature: Bulk Payment Gateway
    As a treasury officer
    I want to orchestrate bulk payments via CSV instructions
    So that I can efficiently pay multiple vendors at once

    Scenario: A valid payment batch is initiated and authorized
        Given I am authorized as "payer@nexus.app" for organisation "org-p1"
        When I upload a bulk payment CSV with 2 instructions:
            | amount | currency | recipient_name | recipient_account |
            | 150.00 | EUR      | Vendor A       | ACC-1             |
            | 500.50 | GBP      | Vendor B       | ACC-2             |
        And I authorize the payment batch
        Then a bulk payment batch should be initiated with 2 items
        And 2 individual transfer requests should be dispatched

    Scenario: A payment batch with explicit invoice IDs prevents double payment
        Given I am authorized as "payer@nexus.app" for organisation "org-p2"
        And an ingested invoice "inv-abc" exists for 250.00 EUR
        When I upload a bulk payment CSV with an explicit invoice:
            | amount | currency | recipient_name | recipient_account | invoice_id |
            | 250.00 | EUR      | Direct Vendor  | ACC-3             | inv-abc    |
        And I authorize the payment batch
        Then the invoice "inv-abc" should be marked as matched
        And a transfer request for 250.00 EUR should be dispatched
