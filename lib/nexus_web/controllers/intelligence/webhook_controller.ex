defmodule NexusWeb.Intelligence.WebhookController do
  use NexusWeb, :controller
  alias Nexus.Intelligence.Commands.AnalyzeSentiment
  require Logger

  @doc """
  Accepts a webhook payload simulating an email or comms stream from a vendor.
  Expected payload: `{"source": "ticket-id or email", "text": "The content to analyze..."}`
  """
  def create(conn, %{"source" => source, "text" => text}) do
    Logger.info("[WebhookController] Received comms from #{source}")

    analysis_id = "anm-" <> Nexus.Schema.generate_uuidv7()

    # We use a static demo org id here, but in reality this would be inferred by the API key
    # or the source email domain matching a tenant in the DB.
    demo_org_id = "1d8f1de3-47c1-48f2-b501-f355e1756173"

    command = %AnalyzeSentiment{
      analysis_id: analysis_id,
      org_id: demo_org_id,
      source_id: source,
      text: text
    }

    case Nexus.App.dispatch(command) do
      :ok ->
        conn
        |> put_status(:accepted)
        |> json(%{
          status: "ok",
          message:
            "Communication payload ingested and queued for Natural Language NLP sentiment scoring."
        })

      {:error, reason} ->
        Logger.error("[WebhookController] Comm payload rejected: #{inspect(reason)}")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to dispatch command for tensor scoring."})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required 'source' or 'text' fields in payload."})
  end
end
