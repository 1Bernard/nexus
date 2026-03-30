Feature: Market Data Feed
    As a treasury system
    I want to ingest real-time market data
    So that I can update exposure calculations with latest exchange rates.

    Scenario: Ingesting a real-time market tick
        Given the Polygon API is connected
        When a market tick is received for "EUR/USD" at price "1.0850"
        Then the "EUR/USD" price is updated in the fast-access cache
        And a MarketTickRecorded event is emitted

    Scenario: Handling tick data gaps
        Given the last market tick for "EUR/USD" was received 20 minutes ago
        When the dashboard queries the system status
        Then a "Stale Data" warning is flagged for the currency pair
