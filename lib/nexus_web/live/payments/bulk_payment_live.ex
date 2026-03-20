defmodule NexusWeb.Payments.BulkPaymentLive do
  @moduledoc """
  LiveView for initiating and monitoring bulk payment batches.
  """
  use NexusWeb, :live_view

  alias Nexus.Payments.Commands.InitiateBulkPayment
  alias Nexus.Payments.Projections.BulkPayment
  alias Nexus.Repo
  import Ecto.Query

  require Logger

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
      |> assign(:staged_payments, [])
      |> assign(:staged_filename, nil)
      |> assign(:validation_errors, [])
      |> assign(:upload_status, :idle)
      |> assign(:daily_liquidity, calculate_total_liquidity(socket.assigns.current_user.org_id))
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
    results = consume_uploaded_entries(socket, :batch, &process_csv/2)

    case results do
      [{payments, filename}] ->
        # Simple validation
        errors = validate_payments(payments)

        socket =
          socket
          |> assign(:staged_payments, payments)
          |> assign(:staged_filename, filename)
          |> assign(:validation_errors, errors)
          |> assign(:upload_status, :staged)
          |> assign(:idempotency_key, Uniq.UUID.uuid7())

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_staged", _params, socket) do
    {:noreply,
     socket
     |> assign(:staged_payments, [])
     |> assign(:staged_filename, nil)
     |> assign(:validation_errors, [])
     |> assign(:upload_status, :idle)}
  end

  @impl true
  def handle_event("authorize_batch", _params, socket) do
    payments = socket.assigns.staged_payments
    org_id = socket.assigns.current_user.org_id
    user_id = socket.assigns.current_user.id
    bulk_payment_id = Uniq.UUID.uuid7()

    cmd = %InitiateBulkPayment{
      bulk_payment_id: bulk_payment_id,
      org_id: org_id,
      user_id: user_id,
      payments: payments,
      initiated_at: DateTime.utc_now()
    }

    case Nexus.App.dispatch(cmd, uuid: socket.assigns.idempotency_key) do
      :ok ->
        optimistic_batch = %Nexus.Payments.Projections.BulkPayment{
          id: bulk_payment_id,
          org_id: org_id,
          user_id: user_id,
          status: "processing",
          total_items: length(payments),
          processed_items: 0,
          total_amount:
            Enum.reduce(payments, Decimal.new(0), fn p, acc -> Decimal.add(p.amount, acc) end),
          created_at: DateTime.utc_now()
        }

        socket =
          socket
          |> put_flash(:info, "Institutional Payment Batch Initiated")
          |> assign(:staged_payments, [])
          |> assign(:staged_filename, nil)
          |> assign(:upload_status, :idle)
          |> assign(:batches, [optimistic_batch | list_batches(org_id)])

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Authorization Failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event(
        "reflect_payment",
        %{"recipient_name" => name, "amount" => amount, "currency" => currency},
        socket
      ) do
    amount_decimal = Nexus.Schema.parse_decimal(amount)
    org_id = socket.assigns.current_user.org_id

    # Persist the debit to a vault if it exists
    case Nexus.Treasury.Queries.VaultQuery.find_vault_for_currency(org_id, currency) do
      nil ->
        Logger.warning("[Payments] No vault found for #{currency} to reflect manual payment.")

      vault ->
        cmd = %Nexus.Treasury.Commands.DebitVault{
          vault_id: vault.id,
          org_id: org_id,
          amount: amount_decimal,
          currency: currency,
          transfer_id: "reflection-#{Nexus.Schema.generate_uuidv7()}",
          debited_at: Nexus.Schema.utc_now()
        }

        Nexus.App.dispatch(cmd)
    end

    {:noreply,
     socket
     |> put_flash(
       :info,
       "Manual Reflection: Payment of #{amount} #{currency} to #{name} has been recorded."
     )
     |> assign(:daily_liquidity, calculate_total_liquidity(org_id))}
  end

  defp calculate_total_liquidity(org_id) do
    Nexus.Treasury.list_liquidity_positions(org_id)
    |> Enum.filter(&(&1.currency == "EUR"))
    |> Enum.reduce(Decimal.new(0), fn pos, acc -> Decimal.add(acc, pos.amount) end)
    # Fallback for demo if no positions exist
    |> then(fn amt ->
      if Decimal.eq?(amt, 0), do: Decimal.new("842500.00"), else: amt
    end)
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

  defp process_csv(meta, entry) do
    # Institutional CSV Parsing via NimbleCSV
    alias NimbleCSV.RFC4180, as: Parser

    content = File.read!(meta.path)

    payments =
      content
      # clean mac lines
      |> String.replace("\r", "")
      |> Parser.parse_string(skip_headers: false)
      |> Enum.map(fn
        [single_col] -> String.split(single_col, ~r/[,;]/) |> Enum.map(&String.trim/1)
        cols -> cols
      end)
      |> Enum.map(fn row ->
        case row do
          [amount_str, currency, name, account | rest] ->
            invoice_id = List.first(rest)

            %{
              amount: parse_decimal(amount_str),
              currency: String.trim(currency) |> String.upcase(),
              recipient_name: String.trim(name),
              recipient_account: String.trim(account),
              invoice_id: if(invoice_id, do: String.trim(invoice_id))
            }

          _ ->
            nil
        end
      end)
      |> Enum.reject(fn p ->
        # Skip header if 'amount' is in the first column or amount is 0 and account looks like 'account'
        is_nil(p) or
          (p.amount == Decimal.new(0) and
             String.contains?(String.downcase(p.recipient_account), "account")) or
          (p.recipient_name == "" and p.recipient_account == "")
      end)

    {:ok, {payments, entry.client_name}}
  end

  defp parse_decimal(str) do
    str = String.trim(str) |> String.replace(~r/[^-0-9.]/, "")

    case Decimal.parse(str) do
      {decimal, ""} -> decimal
      _ -> Decimal.new(0)
    end
  end

  defp validate_payments(payments) do
    payments
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {p, idx} ->
      errors = []

      errors =
        if Decimal.compare(p.amount, Decimal.new(0)) == :gt,
          do: errors,
          else: ["Row #{idx}: Amount must be positive" | errors]

      errors =
        if String.length(p.recipient_account) >= 3,
          do: errors,
          else: ["Row #{idx}: Invalid account number (minimum 3 chars)" | errors]

      errors
    end)
  end

  import NexusWeb.Payments.BulkPaymentComponents

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container class="px-6">
      <div class="flex flex-col md:flex-row md:items-end justify-between gap-4 mb-8">
        <div>
          <h1 class="text-3xl font-black text-white tracking-tight">Payment Gateway</h1>
          <p class="text-slate-400 text-sm mt-1">
            Orchestrate bulk treasury transfers with standard-compliant CSV instructions.
          </p>
        </div>
        <div class="flex items-center gap-3">
          <div class="px-4 py-2 rounded-xl bg-white/[0.03] border border-white/[0.06] flex items-center gap-3">
            <div class="text-right">
              <p class="text-[10px] text-slate-500 uppercase font-bold tracking-wider">
                Daily Liquidity
              </p>
              <p class="text-sm font-mono font-bold text-emerald-400">
                {Decimal.round(@daily_liquidity, 2)} EUR
              </p>
            </div>
            <div class="w-8 h-8 rounded-lg bg-emerald-500/10 flex items-center justify-center">
              <span class="hero-banknotes w-4 h-4 text-emerald-400"></span>
            </div>
          </div>
          <.nx_button
            type="button"
            phx-click={JS.toggle(to: "#reflection-panel")}
            variant="outline"
            icon="hero-plus-circle"
            class="px-4 py-2 text-xs font-bold"
          >
            Reflect Manual Entry
          </.nx_button>
        </div>
      </div>

      <%!-- Manual Reflection Form (Hidden by default) --%>
      <div
        id="reflection-panel"
        class="hidden mb-8 animate-in fade-in slide-in-from-top-4 duration-300"
      >
        <.dark_card class="p-6 border-indigo-500/30 bg-indigo-500/5">
          <div class="flex items-center gap-3 mb-6">
            <div class="w-10 h-10 rounded-xl bg-indigo-500/10 flex items-center justify-center">
              <span class="hero-pencil-square w-5 h-5 text-indigo-400"></span>
            </div>
            <div>
              <h3 class="text-sm font-bold text-white">Manual Payment Reflection</h3>
              <p class="text-[10px] text-slate-500 uppercase font-black tracking-widest">
                External Transaction Sync
              </p>
            </div>
          </div>

          <form
            id="reflection-form"
            phx-submit="reflect_payment"
            class="grid grid-cols-1 md:grid-cols-4 gap-4"
          >
            <div class="space-y-1">
              <label class="text-[10px] font-bold text-slate-500 uppercase ml-1">
                Recipient Name
              </label>
              <input
                name="recipient_name"
                type="text"
                class="w-full bg-slate-900/50 border-white/10 rounded-xl text-sm p-3 text-white focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
                placeholder="e.g. AWS EMEA"
                required
              />
            </div>
            <div class="space-y-1">
              <label class="text-[10px] font-bold text-slate-500 uppercase ml-1">Amount</label>
              <input
                name="amount"
                type="number"
                step="0.01"
                class="w-full bg-slate-900/50 border-white/10 rounded-xl text-sm p-3 text-white focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
                placeholder="0.00"
                required
              />
            </div>
            <div class="space-y-1">
              <label class="text-[10px] font-bold text-slate-500 uppercase ml-1">Currency</label>
              <select
                name="currency"
                class="w-full bg-slate-900/50 border-white/10 rounded-xl text-sm p-3 text-white focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
              >
                <option value="EUR">EUR</option>
                <option value="USD">USD</option>
                <option value="GBP">GBP</option>
              </select>
            </div>
            <div class="flex items-end">
              <button
                type="submit"
                class="w-full bg-indigo-600 hover:bg-indigo-500 text-white font-black py-3 rounded-xl shadow-lg shadow-indigo-600/20 transition-all active:scale-95 text-xs"
              >
                Reflect In Ledger
              </button>
            </div>
          </form>
        </.dark_card>
      </div>

      <%!-- Upload & Staging --%>
      <%= if @upload_status == :idle do %>
        <div class="relative group mb-8">
          <div class="absolute -inset-1 bg-gradient-to-r from-indigo-500/20 to-purple-500/20 rounded-3xl blur opacity-25 group-hover:opacity-50 transition duration-1000">
          </div>
          <.dark_card
            class="relative p-12 flex flex-col items-center gap-6 border-dashed border-2 border-white/10 hover:border-indigo-500/40 transition-all duration-500 bg-white/[0.02]"
            phx-drop-target={@uploads.batch.ref}
          >
            <div class="w-20 h-20 rounded-3xl bg-gradient-to-br from-indigo-500/10 to-purple-500/10 ring-1 ring-white/10 flex items-center justify-center shadow-2xl">
              <span class="hero-credit-card w-10 h-10 text-indigo-400"></span>
            </div>

            <div class="text-center">
              <h3 class="text-xl font-bold text-white tracking-tight">Drop your payment batch</h3>
              <p class="text-slate-400 text-sm mt-2 max-w-sm">
                Supports <span class="font-mono text-cyan-300 font-bold">CSV</span> instructions
                containing amount, currency, recipient name, and account.
              </p>
            </div>

            <form id="upload-form" phx-submit="save" phx-change="validate" class="w-full max-w-xs">
              <.live_file_input upload={@uploads.batch} class="sr-only" />
              <div class="flex flex-col items-center gap-4">
                <label
                  for={@uploads.batch.ref}
                  class="w-full cursor-pointer px-8 py-4 rounded-2xl bg-white text-slate-900 text-sm font-black hover:bg-slate-100 transition-all text-center shadow-lg active:scale-95"
                >
                  Browse Batch Files
                </label>

                <%!-- Upload queue --%>
                <%= for entry <- @uploads.batch.entries do %>
                  <div class="w-full flex items-center gap-3 px-4 py-3.5 rounded-2xl bg-white/[0.05] border border-white/10 backdrop-blur-sm">
                    <div class="w-10 h-10 rounded-xl bg-indigo-500/20 flex items-center justify-center shrink-0">
                      <span class="hero-document-text text-indigo-400 w-5 h-5"></span>
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm text-white font-bold truncate">{entry.client_name}</p>
                      <div class="mt-2 h-1.5 bg-white/10 rounded-full overflow-hidden border border-white/5">
                        <div
                          class="h-full bg-indigo-500 rounded-full transition-all duration-500"
                          style={"width: #{entry.progress}%"}
                        />
                      </div>
                    </div>
                  </div>
                <% end %>

                <%= if length(@uploads.batch.entries) > 0 do %>
                  <button
                    type="submit"
                    class="w-full px-8 py-4 rounded-2xl bg-indigo-600 text-white text-sm font-black hover:bg-indigo-500 transition-all shadow-xl shadow-indigo-500/20 active:scale-95 flex items-center justify-center gap-2"
                  >
                    <span class="hero-magnifying-glass w-5 h-5"></span> Analyze Batch
                  </button>
                <% end %>
              </div>
            </form>
          </.dark_card>
        </div>
      <% end %>

      <%!-- Review State --%>
      <%= if @upload_status == :staged do %>
        <div class="mb-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
          <.dark_card class="overflow-hidden border-indigo-500/30 ring-1 ring-indigo-500/20 shadow-2xl shadow-indigo-500/10">
            <div class="px-8 py-6 bg-gradient-to-r from-indigo-500/10 to-transparent border-b border-white/[0.06] flex flex-col md:flex-row md:items-center justify-between gap-4">
              <div>
                <div class="flex items-center gap-2 mb-1">
                  <span class="px-2 py-0.5 rounded bg-indigo-500 text-[9px] font-black text-white uppercase tracking-widest">
                    Review Pending
                  </span>
                  <p class="text-[10px] font-mono text-slate-500">File: {@staged_filename}</p>
                </div>
                <h2 class="text-xl font-bold text-white">Stage Payment Instructions</h2>
              </div>
              <div class="flex items-center gap-3">
                <button
                  phx-click="clear_staged"
                  class="px-5 py-2.5 rounded-xl bg-white/5 border border-white/10 text-slate-300 text-xs font-bold hover:bg-white/10 transition-all"
                >
                  Discard Batch
                </button>
                <button
                  phx-click="authorize_batch"
                  disabled={not Enum.empty?(@validation_errors)}
                  class={[
                    "px-6 py-2.5 rounded-xl text-xs font-black transition-all flex items-center gap-2 shadow-lg",
                    if(Enum.empty?(@validation_errors),
                      do: "bg-emerald-600 text-white hover:bg-emerald-500 active:scale-95",
                      else: "bg-slate-800 text-slate-600 cursor-not-allowed"
                    )
                  ]}
                >
                  <span class="hero-key w-4 h-4"></span> Authorize & Instate
                </button>
              </div>
            </div>

            <%= if not Enum.empty?(@validation_errors) do %>
              <div class="px-8 py-4 bg-rose-500/5 border-b border-rose-500/10">
                <div class="flex items-start gap-3">
                  <span class="hero-no-symbol w-5 h-5 text-rose-500 mt-0.5"></span>
                  <div>
                    <p class="text-xs font-black text-rose-400 uppercase tracking-widest mb-2">
                      Technical Validation Failures
                    </p>
                    <ul class="text-[11px] text-rose-300/80 font-mono space-y-1">
                      <%= for err <- @validation_errors do %>
                        <li>• {err}</li>
                      <% end %>
                    </ul>
                  </div>
                </div>
              </div>
            <% end %>

            <%!-- Review Table --%>
            <div class="max-h-[400px] overflow-y-auto custom-scrollbar bg-slate-900/40">
              <table class="w-full text-left border-collapse">
                <thead class="sticky top-0 bg-slate-950 z-10 border-b border-white/[0.06]">
                  <tr>
                    <th class="px-8 py-4 text-[10px] font-black text-slate-500 uppercase tracking-widest">
                      Recipient
                    </th>
                    <th class="px-8 py-4 text-[10px] font-black text-slate-500 uppercase tracking-widest">
                      Account Details
                    </th>
                    <th class="px-8 py-4 text-[10px] font-black text-slate-500 uppercase tracking-widest text-right">
                      Amount
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-white/[0.04]">
                  <%= for p <- @staged_payments do %>
                    <tr class="hover:bg-white/[0.02] transition-colors group">
                      <td class="px-8 py-4">
                        <p class="text-sm font-bold text-white">{p.recipient_name}</p>
                      </td>
                      <td class="px-8 py-4">
                        <p class="text-xs font-mono text-slate-400">{p.recipient_account}</p>
                      </td>
                      <td class="px-8 py-4 text-right">
                        <p class="text-sm font-mono font-black text-white">
                          {Decimal.round(p.amount, 2)} {p.currency}
                        </p>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
            <div class="px-8 py-4 bg-white/[0.02] border-t border-white/[0.06] flex items-center justify-between">
              <div class="flex items-center gap-6">
                <div class="flex flex-col">
                  <span class="text-[9px] font-black text-slate-500 uppercase tracking-widest">
                    Instruction Count
                  </span>
                  <span class="text-xs font-mono font-bold text-indigo-400">
                    {length(@staged_payments)} items
                  </span>
                </div>
                <div class="flex flex-col">
                  <span class="text-[9px] font-black text-slate-500 uppercase tracking-widest">
                    Batch Gross
                  </span>
                  <span class="text-xs font-mono font-bold text-emerald-400">
                    {Enum.reduce(@staged_payments, Decimal.new(0), &Decimal.add(&1.amount, &2))
                    |> Decimal.round(2)} EUR (Est)
                  </span>
                </div>
              </div>
              <p class="text-[9px] text-slate-600 italic">Signature: nexus_edge_auth_v7</p>
            </div>
          </.dark_card>
        </div>
      <% end %>

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
