Feature: Propagation of Correlation Metadata (Traceability)
  As a System Administrator
  I want all actions to propagate correlation and causation metadata
  So that I can trace every side effect back to its originating command

  Scenario: Propagation of correlation_id from command to audit log and notification
    Given a provisioned organization "Trace Test Org"
    And a custom correlation_id "019d16a7-0000-0000-0000-000000000000"
    When I register a new user "Trace Tester" with the custom correlation_id
    Then an audit log entry should exist with correlation_id "019d16a7-0000-0000-0000-000000000000"
    And a system notification should exist with correlation_id "019d16a7-0000-0000-0000-000000000000"
    And the notification type should be "user_registered"
