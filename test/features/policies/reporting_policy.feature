Feature: Reporting Policy
  As a security-conscious system
  I want to restrict access to reporting data
  So that only authorized users can view audit logs and compliance reports

  Scenario Outline: Accessing Audit Logs
    Given a user with role "<role>" in the reporting context
    When I check if the user can "view" "audit_logs"
    Then the action should be "<result>"

    Examples:
      | role         | result  |
      | auditor      | allowed |
      | system_admin | allowed |
      | trader       | denied  |

  Scenario: Unauthenticated User Access
    Given no authenticated user in the reporting context
    When I check if the user can "view" "audit_logs"
    Then the action should be "denied"
