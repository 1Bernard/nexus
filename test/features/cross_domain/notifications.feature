Feature: Global UI Notifications
    As a Trader or Admin
    I want to receive real-time notifications for critical system events
    So that I can respond to urgent treasury tasks immediately

    Scenario: Receive a treasury policy alert notification
        Given the treasury system is active for organization "Stark Industries"
        And a trader "tony@stark.com" is currently online
        When a treasury policy alert is triggered for "EUR/USD" above threshold "50000"
        Then a notification "Policy Alert: EUR/USD exposure exceeded threshold" should be emitted
        And the notification should be available in the trader's unread list

    Scenario: Mark a notification as read
        Given a trader "tony@stark.com" has 1 unread notification
        When the trader marks the notification as read
        Then the notification should be moved to the read history
        And the unread count should decrement to 0
