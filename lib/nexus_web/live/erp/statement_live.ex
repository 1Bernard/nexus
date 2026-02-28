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

    socket =
      socket
      |> assign(:statements, ERP.list_statements(org_id))
      |> assign(:expanded_statement_id, nil)
      |> assign(:expanded_lines, [])
      |> assign(:upload_error, nil)
      |> assign(:upload_status, :idle)
      |> allow_upload(:statement,
        accept: @accepted_formats,
        max_entries: 1,
        max_file_size: 5 * 1024 * 1024
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, assign(socket, upload_error: nil)}
  end

  @impl true
  def handle_event("upload", _params, socket) do
    org_id = socket.assigns.current_user.org_id

    results =
      consume_uploaded_entries(socket, :statement, fn %{path: path}, entry ->
        raw_content = File.read!(path)
        filename = entry.client_name
        format = detect_format(filename)
        statement_id = Schema.generate_uuidv7()

        command = %Nexus.ERP.Commands.UploadStatement{
          statement_id: statement_id,
          org_id: org_id,
          filename: filename,
          format: format,
          raw_content: raw_content
        }

        case App.dispatch(command, consistency: :strong) do
          :ok -> {:ok, :uploaded}
          {:error, reason} -> {:ok, {:error, reason}}
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
      lines = ERP.list_statement_lines(id)
      {:noreply, assign(socket, expanded_statement_id: id, expanded_lines: lines)}
    end
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :statement, ref)}
  end

  @impl true
  def handle_info({:statement_uploaded, _statement_id}, socket) do
    org_id = socket.assigns.current_user.org_id
    {:noreply, assign(socket, :statements, ERP.list_statements(org_id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#080B11] text-white px-6 py-8">
      <%!-- Page header --%>
      <div class="max-w-5xl mx-auto">
        <div class="mb-8">
          <h1 class="text-2xl font-serif italic font-bold text-white tracking-tight">
            Document Gateway
          </h1>
          <p class="text-slate-400 text-sm mt-1">
            Upload MT940 SWIFT or CSV bank statements to begin reconciliation.
          </p>
        </div>

        <%!-- Upload zone --%>
        <div
          class="mb-8 rounded-2xl border-2 border-dashed border-white/10 bg-white/[0.02] p-10 flex flex-col items-center gap-4 transition-colors hover:border-indigo-500/30 hover:bg-white/[0.03]"
          phx-drop-target={@uploads.statement.ref}
        >
          <div class="w-14 h-14 rounded-2xl bg-indigo-500/10 ring-1 ring-indigo-500/20 flex items-center justify-center">
            <span class="hero-document-arrow-up w-7 h-7 text-indigo-400"></span>
          </div>
          <div class="text-center">
            <p class="text-white font-medium">Drag &amp; drop your statement</p>
            <p class="text-slate-400 text-sm mt-1">
              Supports <span class="font-mono text-indigo-300">MT940</span>
              (.sta, .txt) and <span class="font-mono text-cyan-300">CSV</span>
              — max 5 MB
            </p>
          </div>

          <form id="upload-form" phx-submit="upload" phx-change="validate">
            <.live_file_input upload={@uploads.statement} class="sr-only" />
            <label
              for={@uploads.statement.ref}
              class="cursor-pointer px-5 py-2.5 rounded-xl bg-indigo-600 text-white text-sm font-semibold hover:bg-indigo-500 transition-colors"
            >
              Browse Files
            </label>

            <%!-- Upload queue --%>
            <%= for entry <- @uploads.statement.entries do %>
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
                <button
                  type="button"
                  phx-click="cancel_upload"
                  phx-value-ref={entry.ref}
                  class="text-slate-500 hover:text-rose-400 transition-colors"
                >
                  <span class="hero-x-mark w-4 h-4"></span>
                </button>
              </div>

              <%= for err <- upload_errors(@uploads.statement, entry) do %>
                <p class="text-rose-400 text-xs mt-1">{upload_error_to_string(err)}</p>
              <% end %>
            <% end %>

            <%= if length(@uploads.statement.entries) > 0 do %>
              <button
                type="submit"
                class="mt-4 px-6 py-2.5 rounded-xl bg-emerald-600 text-white text-sm font-semibold hover:bg-emerald-500 transition-colors"
              >
                Upload Statement
              </button>
            <% end %>
          </form>

          <%!-- Feedback --%>
          <%= if @upload_error do %>
            <p class="text-rose-400 text-xs font-mono mt-2">{@upload_error}</p>
          <% end %>
          <%= if @upload_status == :success do %>
            <p class="text-emerald-400 text-xs font-mono mt-2">✓ Statement uploaded and parsed</p>
          <% end %>
        </div>

        <%!-- Statement list --%>
        <div class="rounded-2xl border border-white/[0.06] bg-white/[0.02] overflow-hidden">
          <div class="px-5 py-3.5 border-b border-white/[0.06] flex items-center gap-3">
            <span class="hero-rectangle-stack w-4 h-4 text-slate-500"></span>
            <h2 class="text-sm font-semibold text-white">Uploaded Statements</h2>
            <span class="ml-auto text-xs text-slate-500">{length(@statements)} total</span>
          </div>

          <%= if Enum.empty?(@statements) do %>
            <.statements_empty />
          <% else %>
            <div class="flex flex-col gap-1.5 p-3">
              <%= for statement <- @statements do %>
                <div>
                  <button
                    class="w-full text-left"
                    phx-click="expand_statement"
                    phx-value-id={statement.id}
                  >
                    <.statement_row statement={statement} />
                  </button>

                  <%!-- Expanded lines --%>
                  <%= if @expanded_statement_id == statement.id do %>
                    <div class="mt-1 mx-2 rounded-xl bg-white/[0.02] border border-white/[0.05] overflow-hidden">
                      <div class="px-4 py-2.5 border-b border-white/[0.06]">
                        <p class="text-[10px] text-slate-500 uppercase tracking-widest font-bold">
                          Parsed Transactions
                        </p>
                      </div>
                      <%= if Enum.empty?(@expanded_lines) do %>
                        <p class="text-slate-600 text-xs py-6 text-center">No lines found</p>
                      <% else %>
                        <div class="divide-y divide-white/[0.04]">
                          <%= for line <- @expanded_lines do %>
                            <.statement_line_row line={line} />
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

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
