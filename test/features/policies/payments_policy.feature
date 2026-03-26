Feature: Payments Policy
  As a security-conscious system
  I want to restrict access to payment operations
  So that only authorized users can initiate and approve financial transfers

  Scenario Outline: Accessing Payments Data
    Given a user with role "<role>" in the payments context
    When I check if the user can "<action>" "payments"
    Then the action should be "<result>"

    Examples:
      | role         | action   | result  |
      | viewer       | view     | allowed |
      | treasury_ops | initiate | allowed |
      | system_admin | approve  | allowed |
      | viewer       | initiate | denied  |

  Scenario: Unauthenticated User Access
    Given no authenticated user in the payments context
    When I check if the user can "initiate" "payments"
    Then the action should be "denied"
