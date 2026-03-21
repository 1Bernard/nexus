defmodule NexusWeb.ERP.StatementLive do
  @moduledoc """
  Document Gateway — bank statement upload page.
  Supports MT940 SWIFT and CSV formats via drag-and-drop LiveView file uploads.
  """
  use NexusWeb, :live_view
  import NexusWeb.ERP.StatementComponents

  alias Nexus.App
  alias Nexus.ERP
  alias Nexus.Schema

  @accepted_formats [".sta", ".txt", ".mt940", ".csv"]

  @impl true
  def mount(_params, _session, socket) do
    org_id = socket.assigns.current_user.org_id

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Nexus.PubSub, "erp_statements:#{org_id}")
    end

    org_id_for_query =
      if Enum.member?(socket.assigns.current_user.roles, "system_admin"), do: :all, else: org_id

    socket =
      socket
      |> assign(:page_title, "Document Gateway")
      |> assign(:current_path, "/statements")
      |> assign(:statements, ERP.list_statements(org_id_for_query, "", ""))
      |> assign(:expanded_statement_id, nil)
      |> assign(:expanded_lines, [])
      |> assign(:upload_error, nil)
      |> assign(:upload_status, :idle)
      |> assign(:filename_warning, false)
      |> assign(:search_query, "")
      |> assign(:date_filter, "")
      |> allow_upload(:statement,
        accept: @accepted_formats,
        max_entries: 1,
        max_file_size: 5 * 1024 * 1024
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    org_id = socket.assigns.current_user.org_id

    filename_warning =
      socket.assigns.uploads.statement.entries
      |> Enum.any?(fn entry -> ERP.statement_exists_by_filename?(org_id, entry.client_name) end)

    socket =
      socket
      |> assign(upload_error: nil)
      |> assign(filename_warning: filename_warning)
      |> assign(idempotency_key: Uniq.UUID.uuid7())

    {:noreply, socket}
  end

  @impl true
  def handle_event("upload", _params, socket) do
    org_id = socket.assigns.current_user.org_id

    results =
      consume_uploaded_entries(socket, :statement, fn %{path: path}, entry ->
        raw_content = File.read!(path)
        filename = entry.client_name
        format = detect_format(filename)
        content_hash = :crypto.hash(:sha256, raw_content) |> Base.encode16()

        cond do
          ERP.statement_exists_by_hash?(org_id, content_hash) ->
            {:error, "A statement with identical content has already been uploaded."}

          ERP.statement_exists_by_filename?(org_id, filename) ->
            # Filename exists but content is different (new version) - we allow it but it will have a warning in the UI
            proceed_with_upload(
              org_id,
              filename,
              format,
              raw_content,
              socket.assigns.idempotency_key
            )

          true ->
            proceed_with_upload(
              org_id,
              filename,
              format,
              raw_content,
              socket.assigns.idempotency_key
            )
        end
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    socket =
      if Enum.empty?(errors) do
        socket
        |> assign(:upload_status, :success)
        |> assign(:upload_error, nil)
        |> assign(:statements, ERP.list_statements(org_id))
      else
        [{:error, reason} | _] = errors
        assign(socket, upload_error: inspect(reason), upload_status: :error)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("expand_statement", %{"id" => id}, socket) do
    if socket.assigns.expanded_statement_id == id do
      {:noreply, assign(socket, expanded_statement_id: nil, expanded_lines: [])}
    else
      org_id = socket.assigns.current_user.org_id
      lines = ERP.list_statement_lines(org_id, id)
      {:noreply, assign(socket, expanded_statement_id: id, expanded_lines: lines)}
    end
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :statement, ref)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, search_query: query)}
  end

  @impl true
  def handle_event("filter_date", %{"date" => date}, socket) do
    {:noreply, assign(socket, date_filter: date)}
  end

  @impl true
  def handle_event("download_original", %{"id" => id}, socket) do
    statement = Enum.find(socket.assigns.statements, &(&1.id == id))

    if statement do
      # In a real app, this would be a proper send_download or a link to a controller.
      # For the demo, we'll push an event that the hooks can handle to download a blob.
      org_id = socket.assigns.current_user.org_id
      raw_content = ERP.get_statement_content(org_id, id)

      socket =
        push_event(socket, "download-file", %{
          filename: statement.filename,
          content: raw_content,
          type: "text/plain"
        })

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Statement not found")}
    end
  end

  @impl true
  def handle_info({info, _id}, socket) when info in [:statement_uploaded, :statement_rejected] do
    org_id = socket.assigns.current_user.org_id

    {:noreply,
     assign(
       socket,
       :statements,
       ERP.list_statements(org_id, socket.assigns.search_query, socket.assigns.date_filter)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container class="px-6">
      <div class="flex flex-col md:flex-row md:items-end justify-between gap-4 mb-8">
        <div>
          <div class="flex items-center gap-2 mb-1">
            <span class="flex h-2 w-2 relative">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75">
              </span>
              <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
            </span>
            <span class="text-[10px] font-bold text-emerald-400 uppercase tracking-widest">
              SWIFT Network Active
            </span>
          </div>
          <h1 class="text-3xl font-black text-white tracking-tight">Document Gateway</h1>
          <p class="text-slate-400 text-sm mt-1">
            Institutional-grade ingestion for MT940 SWIFT and CSV bank statements.
          </p>
        </div>
        <div class="flex items-center gap-3">
          <div class="px-4 py-2 rounded-xl bg-white/[0.03] border border-white/[0.06] flex items-center gap-3">
            <div class="text-right">
              <p class="text-[10px] text-slate-500 uppercase font-bold tracking-wider">
                Auto-Parse Rate
              </p>
              <p class="text-sm font-mono font-bold text-white">99.8%</p>
            </div>
            <div class="w-8 h-8 rounded-lg bg-indigo-500/10 flex items-center justify-center">
              <span class="hero-cpu-chip w-4 h-4 text-indigo-400"></span>
            </div>
          </div>
        </div>
      </div>
      <%!-- Upload zone --%>
      <div class="relative group mb-8">
        <div class="absolute -inset-1 bg-gradient-to-r from-indigo-500/20 to-cyan-500/20 rounded-3xl blur opacity-25 group-hover:opacity-50 transition duration-1000">
        </div>
        <.dark_card
          class="relative p-12 flex flex-col items-center gap-6 border-dashed border-2 border-white/10 hover:border-indigo-500/40 transition-all duration-500 bg-white/[0.02]"
          phx-drop-target={@uploads.statement.ref}
        >
          <div class="w-20 h-20 rounded-3xl bg-gradient-to-br from-indigo-500/10 to-cyan-500/10 ring-1 ring-white/10 flex items-center justify-center shadow-2xl">
            <span class="hero-document-arrow-up w-10 h-10 text-indigo-400 animate-pulse"></span>
          </div>
          <div class="text-center">
            <h3 class="text-xl font-bold text-white">Drag &amp; drop your statement</h3>
            <p class="text-slate-400 text-sm mt-2 max-w-sm">
              Nexus Intelligent Parser supports
              <span class="font-mono text-indigo-300 font-bold">MT940</span>
              (.sta, .txt)
              and <span class="font-mono text-cyan-300 font-bold">CSV</span>
              formats up to 5 MB.
            </p>
          </div>

          <form id="upload-form" phx-submit="upload" phx-change="validate" class="w-full max-w-xs">
            <.live_file_input upload={@uploads.statement} class="sr-only" />
            <div class="flex flex-col items-center gap-4">
              <label
                for={@uploads.statement.ref}
                class="w-full cursor-pointer px-8 py-4 rounded-2xl bg-white text-slate-900 text-sm font-black hover:bg-slate-100 transition-all text-center shadow-lg active:scale-95"
              >
                Browse Systems
              </label>

              <%!-- Upload queue --%>
              <%= for entry <- @uploads.statement.entries do %>
                <div class="w-full flex items-center gap-3 px-4 py-3.5 rounded-2xl bg-white/[0.05] border border-white/10 backdrop-blur-sm animate-in fade-in slide-in-from-bottom-2">
                  <div class="w-10 h-10 rounded-xl bg-indigo-500/20 flex items-center justify-center shrink-0">
                    <span class="hero-document text-indigo-400 w-5 h-5"></span>
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
                  <button
                    type="button"
                    phx-click="cancel_upload"
                    phx-value-ref={entry.ref}
                    class="w-8 h-8 rounded-full flex items-center justify-center text-slate-500 hover:text-rose-400 hover:bg-rose-400/10 transition-all"
                  >
                    <span class="hero-x-mark w-5 h-5"></span>
                  </button>
                </div>

                <%= for err <- upload_errors(@uploads.statement, entry) do %>
                  <p class="text-rose-400 text-xs mt-2 font-bold px-4 py-2 rounded-lg bg-rose-400/10 border border-rose-400/20 flex items-center gap-2">
                    <span class="hero-exclamation-circle w-4 h-4"></span>
                    {upload_error_to_string(err)}
                  </p>
                <% end %>
              <% end %>

              <%= if length(@uploads.statement.entries) > 0 do %>
                <button
                  type="submit"
                  class="w-full px-8 py-4 rounded-2xl bg-indigo-600 text-white text-sm font-black hover:bg-indigo-500 transition-all shadow-xl shadow-indigo-500/20 active:scale-95 flex items-center justify-center gap-2"
                >
                  <span class="hero-cloud-arrow-up w-5 h-5"></span> Injest Statement
                </button>
              <% end %>
            </div>
          </form>

          <%!-- Feedback --%>
          <%= if @filename_warning do %>
            <div class="w-full mt-4 p-4 rounded-2xl bg-amber-500/10 border border-amber-500/20 flex flex-col gap-3 animate-in fade-in">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-xl bg-amber-500/20 flex items-center justify-center shrink-0">
                  <span class="hero-exclamation-triangle w-6 h-6 text-amber-500"></span>
                </div>
                <div class="flex-1">
                  <p class="text-[10px] font-black text-amber-500 uppercase tracking-widest">
                    Duplicate Name Detected
                  </p>
                  <p class="text-xs text-amber-200 font-medium mt-0.5">
                    A file named "{hd(@uploads.statement.entries).client_name}" already exists. If this is a new version, proceed. If it's a duplicate, please remove it.
                  </p>
                </div>
              </div>
            </div>
          <% end %>
          <%= if @upload_error do %>
            <div class="w-full mt-4 p-4 rounded-2xl bg-rose-500/10 border border-rose-500/20 flex flex-col gap-3 animate-in shake-1">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-xl bg-rose-500/20 flex items-center justify-center shrink-0">
                  <span class="hero-exclamation-triangle w-6 h-6 text-rose-500"></span>
                </div>
                <div class="flex-1">
                  <p class="text-[10px] font-black text-rose-500 uppercase tracking-widest">
                    Ingestion Failure
                  </p>
                  <p class="text-xs text-rose-200 font-medium mt-0.5">{@upload_error}</p>
                </div>
                <button
                  type="button"
                  phx-click="validate"
                  class="text-rose-400 hover:text-white text-[10px] font-bold uppercase tracking-wider"
                >
                  Clear
                </button>
              </div>
              <div class="p-3 rounded-xl bg-black/20 border border-white/5">
                <p class="text-[9px] text-slate-400 leading-relaxed font-medium">
                  <span class="text-rose-400 font-bold">Correction Tip:</span>
                  Ensure your CSV starts with the standard headers (`ledger_entry_id` or `date,ref,amount...`) and contains no empty data rows.
                </p>
              </div>
            </div>
          <% end %>

          <%= if @upload_status == :success do %>
            <div class="w-full mt-4 p-4 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 flex items-center gap-3 animate-in zoom-in-95">
              <div class="w-10 h-10 rounded-xl bg-emerald-500/20 flex items-center justify-center shrink-0">
                <span class="hero-check-circle w-6 h-6 text-emerald-500"></span>
              </div>
              <div>
                <p class="text-[10px] font-black text-emerald-500 uppercase tracking-widest">
                  Protocol Success
                </p>
                <p class="text-xs text-emerald-200 font-medium mt-0.5">
                  Statement Ingested &amp; Parsed Successfully
                </p>
              </div>
            </div>
          <% end %>
        </.dark_card>
      </div>

      <%!-- Statement list --%>
      <.dark_card>
        <div class="px-5 py-3.5 border-b border-white/[0.06] flex flex-col md:flex-row md:items-center gap-3 justify-between">
          <div class="flex items-center gap-3">
            <span class="hero-rectangle-stack w-4 h-4 text-slate-500"></span>
            <h2 class="text-sm font-semibold text-white">Uploaded Statements</h2>
            <span class="text-xs text-slate-500">{length(@statements)} total</span>
          </div>
          <div class="flex items-center gap-3">
            <div class="relative group">
              <span class="absolute left-3 top-1/2 -translate-y-1/2 hero-magnifying-glass w-3.5 h-3.5 text-slate-500 group-focus-within:text-indigo-400">
              </span>
              <input
                type="text"
                placeholder="Search statements..."
                phx-keyup="search"
                phx-debounce="200"
                class="bg-white/5 border border-white/10 rounded-lg pl-9 pr-3 py-1.5 text-xs text-slate-300 focus:outline-none focus:ring-1 focus:ring-indigo-500/50 focus:border-indigo-500/50 transition-all w-48"
                value={@search_query}
              />
            </div>
            <input
              type="date"
              phx-change="filter_date"
              class="bg-white/5 border border-white/10 rounded-lg px-3 py-1.5 text-xs text-slate-300 focus:outline-none focus:ring-1 focus:ring-indigo-500/50 transition-all"
              value={@date_filter}
            />
          </div>
        </div>

        <%= if Enum.empty?(@statements) do %>
          <.statements_empty />
        <% else %>
          <div class="flex flex-col gap-1.5 p-3">
            <%= for statement <- @statements do %>
              <div>
                <div class="flex items-center gap-1">
                  <button
                    class="flex-1 text-left"
                    phx-click="expand_statement"
                    phx-value-id={statement.id}
                  >
                    <.statement_row statement={statement} />
                  </button>
                  <.nx_button
                    phx-click="download_original"
                    phx-value-id={statement.id}
                    title="Download Original"
                    variant="outline"
                    size="sm"
                    icon="hero-arrow-down-tray"
                    class="ml-2"
                  >
                  </.nx_button>
                </div>

                <%!-- Expanded lines --%>
                <%= if @expanded_statement_id == statement.id do %>
                  <div class="mt-2 mx-2 rounded-2xl bg-white/[0.03] border border-white/[0.08] backdrop-blur-md overflow-hidden animate-in slide-in-from-top-4 duration-500">
                    <div class="px-6 py-4 border-b border-white/[0.06] flex items-center justify-between bg-white/[0.02]">
                      <div class="flex items-center gap-2">
                        <span class="hero-list-bullet w-4 h-4 text-indigo-400"></span>
                        <p class="text-[10px] text-slate-300 uppercase tracking-widest font-black">
                          Parsed Transaction Records
                        </p>
                      </div>
                      <span class="text-[10px] font-mono text-slate-500">
                        {length(@expanded_lines)} entries identified
                      </span>
                    </div>

                    <%= if Enum.empty?(@expanded_lines) do %>
                      <div class="flex flex-col items-center justify-center py-12 text-slate-600">
                        <span class="hero-no-symbol w-8 h-8 mb-2 opacity-20"></span>
                        <p class="text-xs font-medium uppercase tracking-widest">
                          No transaction data identified
                        </p>
                      </div>
                    <% else %>
                      <%!-- Industry Standard Table for high volume --%>
                      <div class="max-h-[500px] overflow-y-auto custom-scrollbar">
                        <table class="w-full text-left border-collapse">
                          <thead class="sticky top-0 bg-slate-900/95 backdrop-blur-xl z-10">
                            <tr class="border-b border-white/[0.06]">
                              <th class="px-6 py-3 text-[10px] font-black text-slate-500 uppercase tracking-widest">
                                Date
                              </th>
                              <th class="px-6 py-3 text-[10px] font-black text-slate-500 uppercase tracking-widest">
                                Narrative & Origin
                              </th>
                              <th class="px-6 py-3 text-[10px] font-black text-slate-500 uppercase tracking-widest text-right">
                                Ledger Impact
                              </th>
                            </tr>
                          </thead>
                          <tbody class="divide-y divide-white/[0.04]">
                            <%= for line <- @expanded_lines do %>
                              <tr class="hover:bg-white/[0.02] transition-colors group/row">
                                <td class="px-6 py-4 text-xs font-mono text-slate-400 whitespace-nowrap">
                                  {line.date}
                                </td>
                                <td class="px-6 py-4">
                                  <div class="flex flex-col gap-1.5">
                                    <div class="flex items-center gap-2">
                                      <span class="text-xs text-slate-200 font-medium leading-relaxed max-w-md">
                                        {line.narrative}
                                      </span>
                                      <%= if line.metadata && Map.has_key?(line.metadata, "spread") do %>
                                        <div class="flex items-center gap-1 px-1.5 py-0.5 rounded bg-amber-500/10 border border-amber-500/20 text-[9px] font-black text-amber-500 uppercase tracking-tighter">
                                          <span class="hero-bolt-solid w-2.5 h-2.5"></span>
                                          {line.metadata["spread"]} Spread
                                        </div>
                                      <% end %>
                                    </div>
                                    <div class="flex items-center gap-3">
                                      <%= if line.metadata && Map.has_key?(line.metadata, "liquidity_provider") do %>
                                        <div class="flex items-center gap-1.5 text-[9px] text-indigo-400 font-bold uppercase tracking-wider bg-indigo-500/10 px-2 py-0.5 rounded-full border border-indigo-500/20">
                                          <span class="hero-building-library w-3 h-3"></span>
                                          {line.metadata["liquidity_provider"]
                                          |> String.replace("LP_", "")}
                                        </div>
                                      <% end %>
                                      <%= if line.metadata && Map.has_key?(line.metadata, "execution_channel") do %>
                                        <div class="flex items-center gap-1.5 text-[9px] text-cyan-400 font-bold uppercase tracking-wider bg-cyan-500/10 px-2 py-0.5 rounded-full border border-cyan-500/20">
                                          <span class="hero-cpu-chip w-3 h-3"></span>
                                          {line.metadata["execution_channel"]}
                                        </div>
                                      <% end %>
                                      <%= if line.error_message do %>
                                        <div class="flex items-center gap-1.5 text-[9px] text-rose-400 font-bold uppercase tracking-wider">
                                          <span class="hero-exclamation-circle w-3 h-3"></span>
                                          {line.error_message}
                                        </div>
                                      <% end %>
                                    </div>
                                  </div>
                                </td>
                                <td class="px-6 py-4 text-right whitespace-nowrap">
                                  <span class={[
                                    "text-xs font-mono font-black",
                                    if(Decimal.lt?(Decimal.new(line.amount || 0), 0),
                                      do: "text-rose-400",
                                      else: "text-emerald-400"
                                    )
                                  ]}>
                                    {NexusWeb.ERP.StatementComponents.format_amount(
                                      line.amount,
                                      line.currency
                                    )}
                                  </span>
                                </td>
                              </tr>
                            <% end %>
                          </tbody>
                        </table>
                      </div>
                      <div class="px-6 py-3 bg-white/[0.02] border-t border-white/[0.06] flex items-center justify-between">
                        <p class="text-[9px] text-slate-500 font-bold uppercase tracking-widest">
                          End of Stream
                        </p>
                        <p class="text-[9px] text-slate-500 font-bold uppercase tracking-widest italic">
                          Encrypted Secure Ingestion
                        </p>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </.dark_card>
    </.page_container>
    """
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp proceed_with_upload(org_id, filename, format, raw_content, idempotency_key) do
    statement_id = Schema.generate_uuidv7()

    command = %Nexus.ERP.Commands.UploadStatement{
      statement_id: statement_id,
      org_id: org_id,
      filename: filename,
      format: format,
      raw_content: raw_content,
      uploaded_at: DateTime.utc_now()
    }

    case App.dispatch(command, consistency: :strong, uuid: idempotency_key) do
      :ok -> {:ok, :uploaded}
      {:error, reason} -> {:error, reason}
    end
  end

  defp detect_format(filename) do
    ext = filename |> Path.extname() |> String.downcase()

    cond do
      ext in ~w(.csv) -> "csv"
      ext in ~w(.sta .txt .mt940) -> "mt940"
      # Default to MT940 for unknown extensions
      true -> "mt940"
    end
  end

  defp upload_error_to_string(:too_large), do: "File too large (max 5 MB)"
  defp upload_error_to_string(:not_accepted), do: "File type not accepted (use .sta, .txt, .csv)"
  defp upload_error_to_string(:too_many_files), do: "Upload one file at a time"
  defp upload_error_to_string(err), do: inspect(err)
end
