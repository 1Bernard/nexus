Feature: Cross-Domain Notifications
  As a User
  I want to be notified when critical events occur in other domains
  So that I can take timely action

  Scenario: Notifying user of a large transfer
    Given a user "trader1" exists with notification preferences enabled
    When a transfer of "1,000,000 EUR" is executed in the Treasury domain
    Then a "transfer_executed" notification should be dispatched to the user
    And the notification should be recorded in the Cross-Domain audit log
