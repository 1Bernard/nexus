Feature: Cross-Subsidiary Netting
    As a treasury manager
    I want to consolidate intercompany payables across subsidiaries
    So that external transaction costs are minimized.

    Scenario: Initialize a netting cycle for EUR
        Given a registered organization "Global Corp" exists
        When I initialize a netting cycle for "EUR" from "2026-03-01" to "2026-03-31"
        Then a netting cycle should be created in "active" status
        And the total netting amount should be "0.00"

    Scenario: Consolidate invoices from multiple subsidiaries
        Given a registered organization "Global Corp" exists
        And an active netting cycle for "EUR" exists
        And Subsidiary "Munich" has an invoice for "1000.00 EUR"
        And Subsidiary "London" has an invoice for "2000.00 EUR"
        When I add both invoices to the netting cycle
        Then the total netting amount should be "3000.00"
        And the cycle should contain "2" entries

    Scenario: Automate invoice inclusion via scanning
        Given a registered organization "Global Corp" exists
        And an active netting cycle for "EUR" exists
        And ERP contains "3" open invoices for "EUR" within the cycle period
        When I trigger the invoice scan for the cycle
        Then the cycle should contain "3" entries
        And the total netting amount should be the sum of those invoices
