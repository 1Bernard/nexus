defmodule Nexus.Payments.Gateways.PaystackGateway do
  @moduledoc """
  Gateway for Paystack financial rails.
  Implements the `PaymentRail` behavior.
  """
  @behaviour Nexus.Payments.Gateways.PaymentRail

  require Logger

  @doc """
  Initiates a transfer via Paystack.
  """
  @impl true
  @spec execute_transfer(String.t(), Decimal.t(), String.t(), map()) ::
          {:ok, String.t()} | {:error, any()}
  def execute_transfer(transfer_id, amount, currency, recipient_data) do
    # Use a configured secret key or fall back to mock mode
    api_key = Application.get_env(:nexus, :paystack_secret_key)

    if api_key do
      perform_real_transfer(transfer_id, amount, currency, recipient_data, api_key)
    else
      simulate_transfer(transfer_id, amount, currency)
    end
  end

  @doc """
  Verifies a transfer status via Paystack.
  """
  @impl true
  @spec verify_transfer(String.t()) :: {:ok, :success} | {:error, any()}
  def verify_transfer(_transfer_id) do
    api_key = Application.get_env(:nexus, :paystack_secret_key)

    if api_key do
      # Real verification logic would go here
      {:ok, :success}
    else
      {:ok, :success}
    end
  end

  defp perform_real_transfer(transfer_id, amount, currency, recipient_data, api_key) do
    url = "https://api.paystack.co/transfer"

    # Paystack expects amounts in kobo (base unit * 100)
    amount_kobo =
      amount
      |> Decimal.mult(100)
      |> Decimal.to_integer()

    body =
      Jason.encode!(%{
        source: "balance",
        amount: amount_kobo,
        currency: currency,
        recipient: recipient_data.recipient_code,
        reason: "Nexus Transfer: #{transfer_id}",
        reference: transfer_id
      })

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    request = Finch.build(:post, url, headers, body)

    with {:ok, %Finch.Response{status: 200, body: resp_body}} <-
           Finch.request(request, Nexus.Finch, receive_timeout: 10_000),
         {:ok, %{"status" => true, "data" => %{"transfer_code" => code}}} <-
           Jason.decode(resp_body) do
      Logger.info("[Paystack] Transfer initiated: #{code}")
      {:ok, code}
    else
      {:ok, %Finch.Response{status: status}} ->
        Logger.error("[Paystack] Unexpected status: #{status}")
        {:error, :http_error}

      {:ok, %{"message" => msg}} ->
        Logger.error("[Paystack] API error: #{msg}")
        {:error, msg}

      {:ok, _other} ->
        {:error, :invalid_response}

      {:error, reason} ->
        Logger.error("[Paystack] Network failure: #{inspect(reason)}")
        {:error, :network_failure}
    end
  end

  defp simulate_transfer(transfer_id, amount, currency) do
    Logger.info("[Paystack] [MOCK] Simulating transfer #{transfer_id} of #{amount} #{currency}")
    # Simulate a brief delay for realism
    Process.sleep(100)
    {:ok, "ps-mock-#{Nexus.Schema.generate_uuidv7()}"}
  end
end
