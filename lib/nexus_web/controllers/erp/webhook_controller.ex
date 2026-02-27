defmodule NexusWeb.ERP.WebhookController do
  use NexusWeb, :controller

  alias Nexus.ERP.Adapters.RateLimiter
  alias Nexus.ERP.Adapters.SapAdapter
  alias Nexus.ERP.Commands.IngestInvoice
  alias Nexus.App

  require Logger

  @doc """
  Accepts a webhook payload from SAP, validates the quota, routes through the outbound
  Talk Back enrichment request, and finally dispatches the command to the CQRS engine.
  """
  def create(
        conn,
        %{"invoice_id" => invoice_id, "entity_id" => entity_id, "org_id" => org_id} = payload
      ) do
    # 1. Enforce strict Rate Limiting API Quotas (100 req / minute per entity)
    case RateLimiter.check_quota(entity_id) do
      :ok ->
        process_payload(conn, org_id, entity_id, invoice_id, payload)

      {:error, :rate_limited} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{error: "Rate limit exceeded. Maximum 100 requests per minute per entity."})
    end
  end

  def create(conn, _params) do
    # Handle malformed requests without required top-level keys
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required SAP webhook fields: invoice_id, entity_id, or org_id."})
  end

  defp process_payload(conn, org_id, entity_id, invoice_id, payload) do
    # 2. "Talk Back" to SAP to verify the webhook payload and enrich it with master data
    case SapAdapter.enrich_invoice(entity_id, invoice_id) do
      {:ok, enriched_data} ->
        dispatch_to_domain(conn, org_id, entity_id, invoice_id, enriched_data, payload)

      {:error, :network_failure} ->
        conn
        |> put_status(:bad_gateway)
        |> json(%{
          error: "Failed to verify webhook payload with SAP Master System due to network failure."
        })

      {:error, _reason} ->
        conn
        |> put_status(:bad_gateway)
        |> json(%{error: "Failed to verify webhook payload with SAP Master System."})
    end
  end

  defp dispatch_to_domain(conn, org_id, entity_id, invoice_id, enriched_data, payload) do
    # 3. Translate HTTP Payload into a formal Domain Command
    command = %IngestInvoice{
      org_id: org_id,
      invoice_id: invoice_id,
      entity_id: entity_id,
      currency: Map.get(payload, "currency", "EUR"),
      amount: Map.get(payload, "amount", "0.0"),
      subsidiary: Map.get(payload, "subsidiary", "Unknown Subsidiary"),
      line_items: Map.get(payload, "line_items", []),
      sap_document_number: "SAP-#{invoice_id}",
      sap_status: Map.get(enriched_data, :sap_status, "Verified")
    }

    # 4. Dispatch the command. Our existing CQRS Aggregates will handle idempotency and validation.
    case App.dispatch(command) do
      :ok ->
        conn
        |> put_status(:accepted)
        |> json(%{
          status: "ok",
          message: "Invoice successfully ingested into the immutable ledger."
        })

      {:error, reason} ->
        Logger.error("Failed to ingest SAP invoice: #{inspect(reason)}")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Business domain rejected the payload: #{inspect(reason)}"})
    end
  end
end
