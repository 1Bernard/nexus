Feature: Treasury Forecast Dispatch
    As a Treasury Risk Manager
    I want to dispatch forecast generation commands
    So that the system records the requirement.

    Scenario: Dispatching a forecast generation command
        Given a valid forecast request for "EUR" with "30" day horizon
        When the command is dispatched to the Nexus ecosystem
        Then the dispatch should be accepted and recorded as successful
