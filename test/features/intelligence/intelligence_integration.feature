Feature: Intelligence Integration
  As a Risk Analyst
  I want the system to detect anomalous financial activity
  So that I can investigate potential threats and fraud

  Scenario: Detecting a high-frequency transfer anomaly
    Given a tenant exists in the intelligence monitor
    When "5" transfers occur within "10" seconds for the same vault
    Then an anomaly should be flagged by the AI Sentinel
    And a risk alert should be dispatched to the security team
