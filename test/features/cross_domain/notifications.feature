Feature: Global Notifications
  As a Nexus user
  I want to receive real-time notifications for important system events
  So that I can react quickly to critical changes

  @notifications
  Scenario: Receiving a policy alert notification
    Given a Treasury policy exists for "EUR/USD" with a threshold of 50000
    When a treasury policy alert is triggered for "EUR/USD" above threshold "50000"
    Then a notification "Policy Alert: EUR/USD" should be available in the unread list
    And the unread count should be "1"

  @command_palette
  Scenario: Using the command palette
    Given I am on the dashboard
    When I press "Cmd+K"
    Then the command palette should be visible
    When I type "Invoices" in the search input
    Then I should see "Search Invoices" in the results
