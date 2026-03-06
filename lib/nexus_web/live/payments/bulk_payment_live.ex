defmodule NexusWeb.Payments.BulkPaymentLive do
  use NexusWeb, :live_view

  alias Nexus.Payments.Commands.InitiateBulkPayment
  alias Nexus.Payments.Projections.BulkPayment
  alias Nexus.Repo
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(
        Nexus.PubSub,
        "payments:bulk_payments:#{socket.assigns.current_user.org_id}"
      )
    end

    socket =
      socket
      |> assign(:page_title, "Bulk Payments")
      |> assign(:batches, list_batches(socket.assigns.current_user.org_id))
      |> allow_upload(:batch, accept: ~w(.csv), max_entries: 1)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    case consume_uploaded_entries(socket, :batch, &process_csv/2) do
      [{:ok, payments}] ->
        bulk_payment_id = Uniq.UUID.uuid7()

        cmd = %InitiateBulkPayment{
          bulk_payment_id: bulk_payment_id,
          org_id: socket.assigns.current_user.org_id,
          user_id: socket.assigns.current_user.id,
          payments: payments
        }

        case Nexus.App.dispatch(cmd) do
          :ok ->
            {:noreply, put_flash(socket, :info, "Bulk payment initiated successfully")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to initiate: #{inspect(reason)}")}
        end

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:bulk_payment_updated, _batch}, socket) do
    {:noreply, assign(socket, :batches, list_batches(socket.assigns.current_user.org_id))}
  end

  defp list_batches(org_id) do
    BulkPayment
    |> where(org_id: ^org_id)
    |> order_by(desc: :created_at)
    |> Repo.all()
  end

  defp process_csv(meta, _entry) do
    # Simple CSV parser for POC
    # Expected format: amount,currency,recipient_name,recipient_account
    content = File.read!(meta.path)

    payments =
      content
      |> String.split("\n")
      |> Enum.reject(&(&1 == "" || String.starts_with?(&1, "amount")))
      |> Enum.map(fn line ->
        [amount_str, currency, name, account] = String.split(line, ",")

        %{
          amount: Decimal.new(amount_str),
          currency: currency,
          recipient_name: name,
          recipient_account: account
        }
      end)

    {:ok, payments}
  end

  import NexusWeb.Payments.BulkPaymentComponents

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container class="px-6">
      <.page_header
        title="Payment Gateway"
        subtitle="Upload CSV payment instructions to orchestrate bulk treasury transfers."
      />

      <%!-- Upload Zone --%>
      <.dark_card
        class="p-10 flex flex-col items-center gap-4 transition-colors hover:border-indigo-500/30 hover:bg-white/[0.03]"
        phx-drop-target={@uploads.batch.ref}
      >
        <div class="w-14 h-14 rounded-2xl bg-indigo-500/10 ring-1 ring-indigo-500/20 flex items-center justify-center">
          <span class="hero-credit-card w-7 h-7 text-indigo-400"></span>
        </div>

        <div class="text-center">
          <p class="text-white font-medium">Drop your payment batch</p>
          <p class="text-slate-400 text-sm mt-1">
            Supports <span class="font-mono text-cyan-300">CSV</span> instructions
            — amount, currency, recipient
          </p>
        </div>

        <form id="upload-form" phx-submit="save" phx-change="validate">
          <.live_file_input upload={@uploads.batch} class="sr-only" />
          <div class="flex justify-center mt-2">
            <label
              for={@uploads.batch.ref}
              class="cursor-pointer px-5 py-2.5 rounded-xl bg-indigo-600 text-white text-sm font-semibold hover:bg-indigo-500 transition-colors"
            >
              Browse Files
            </label>
          </div>

          <%!-- Upload queue --%>
          <%= for entry <- @uploads.batch.entries do %>
            <div class="flex items-center gap-3 mt-4 px-4 py-3 rounded-xl bg-white/[0.04] w-72">
              <span class="hero-document text-slate-400 w-5 h-5 flex-shrink-0"></span>
              <div class="flex-1 min-w-0">
                <p class="text-sm text-white truncate">{entry.client_name}</p>
                <div class="mt-1 h-1 bg-white/10 rounded-full overflow-hidden">
                  <div
                    class="h-full bg-indigo-500 rounded-full transition-all"
                    style={"width: #{entry.progress}%"}
                  />
                </div>
              </div>
            </div>
          <% end %>

          <%= if length(@uploads.batch.entries) > 0 do %>
            <div class="flex justify-center">
              <button
                type="submit"
                class="mt-4 px-6 py-2.5 rounded-xl bg-emerald-600 text-white text-sm font-semibold hover:bg-emerald-500 transition-colors"
              >
                Process Batch
              </button>
            </div>
          <% end %>
        </form>
      </.dark_card>

      <%!-- Batch List --%>
      <.dark_card>
        <div class="px-5 py-3.5 border-b border-white/[0.06] flex items-center gap-3">
          <span class="hero-rectangle-stack w-4 h-4 text-slate-500"></span>
          <h2 class="text-sm font-semibold text-white">Recent Payment Batches</h2>
          <span class="text-xs text-slate-500">{length(@batches)} total</span>
        </div>

        <%= if Enum.empty?(@batches) do %>
          <.batches_empty />
        <% else %>
          <div class="flex flex-col gap-2 p-3">
            <%= for batch <- @batches do %>
              <.batch_row batch={batch} />
            <% end %>
          </div>
        <% end %>
      </.dark_card>
    </.page_container>
    """
  end
end
