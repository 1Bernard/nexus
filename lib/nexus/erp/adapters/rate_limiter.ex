defmodule Nexus.ERP.Adapters.RateLimiter do
  @moduledoc """
  Institutional API Protection Layer.

  Uses Hammer with an ETS backend to ensure we don't exceed SAP's
  API quotas during heavy ingestion periods.
  """

  @doc """
  Checks if we are allowed to 'Talk Back' to SAP.
  Limit: 100 requests per 60 seconds (Institutional Standard).
  """
  def check_quota(sap_entity_id) do
    case Hammer.check_rate("sap_api:#{sap_entity_id}", 60_000, 100) do
      {:allow, _count} -> :ok
      {:deny, _limit} -> {:error, :rate_limited}
    end
  end
end
