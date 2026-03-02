Feature: AI Sentinel (Anomaly & Sentiment)
    As a Treasury Manager
    I want the system to automatically flag statistical anomalies in invoices and analyze sentiment
    So that I can pre-emptively catch fraud and monitor subsidiary risk

    Scenario: Invoice is flagged as an anomaly
        Given a vendor "CorpTech" with a historical average invoice of 1000 EUR
        When an invoice for 500000 EUR is ingested
        Then the AI Sentinel should flag it with an "anomaly_score" greater than 0.8
        And emit an "AnomalyDetected" event

    Scenario: Routine communication is scored
        Given the AI Sentinel is actively monitoring communications
        When the system processes a communication reading "We are very happy with the quick payment."
        Then the AI Sentinel should score the sentiment as "positive"
        And emit a "SentimentScored" event
