Feature: Treasury Policy
  As a security-conscious system
  I want to restrict access to treasury operations
  So that only authorized users can manage vaults and reconciliation

  Scenario Outline: Accessing Treasury Data
    Given a user with role "<role>" in the treasury context
    When I check if the user can "<action>" "<resource>"
    Then the action should be "<result>"

    Examples:
      | role         | action             | resource       | result  |
      | treasury_ops | register_vault     | vault          | allowed |
      | system_admin | simulate_rebalance | vault          | allowed |
      | viewer       | register_vault     | vault          | denied  |
      | treasury_ops | confirm            | reconciliation | allowed |
      | treasury_ops | approve            | reconciliation | allowed |

  Scenario: Unauthenticated User Access
    Given no authenticated user in the treasury context
    When I check if the user can "any" "any"
    Then the action should be "denied"
