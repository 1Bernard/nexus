Feature: Market Tick Ingestion
    As a treasury system
    I want to ingest real-time market ticks
    So that FX positions are valued accurately.

    Scenario: A new market tick is projected to the read model
        Given a market tick for "EUR/USD" at "1.0850" is recorded
        When the market tick projector handles the event
        Then the projected price for "EUR/USD" should be "1.0850"
        And the tick ID should be a valid UUIDv7
