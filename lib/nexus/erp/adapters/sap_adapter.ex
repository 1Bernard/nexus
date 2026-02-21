defmodule Nexus.ERP.Adapters.SapAdapter do
  @moduledoc """
  Institutional "Talk Back" Adapter for SAP ERP.

  Uses Finch for resilient pooling and the local RateLimiter
  to prevent API blacklisting.
  """
  alias Nexus.ERP.Adapters.RateLimiter
  require Logger

  @doc """
  Enriches a local invoice with data from the SAP master record.
  """
  def enrich_invoice(entity_id, invoice_id) do
    with :ok <- RateLimiter.check_quota(entity_id),
         {:ok, response} <- call_sap_api(entity_id, invoice_id) do
      {:ok, response}
    else
      {:error, :rate_limited} = err ->
        Logger.warning("[ERP] Rate limit exceeded for entity: #{entity_id}")
        err

      {:error, reason} ->
        Logger.error("[ERP] SAP API failure: #{inspect(reason)}")
        {:error, :api_failure}
    end
  end

  defp call_sap_api(_entity_id, "error_trigger") do
    {:error, :simulated_api_failure}
  end

  defp call_sap_api(_entity_id, invoice_id) do
    # In a simulation, we mock the Finch call
    # In production, this would be:
    # Finch.build(:get, "#{@sap_base_url}/invoices/#{invoice_id}")
    # |> Finch.request(Nexus.Finch)

    Logger.info("[ERP] Calling SAP for invoice: #{invoice_id}")
    {:ok, %{sap_status: "Verified", enriched_at: DateTime.utc_now()}}
  end
end
