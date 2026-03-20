defmodule Mix.Tasks.Nexus.Verify do
  @moduledoc """
  Audits the Nexus codebase for strict compliance with Coding Standards and the Elite Standard.

  Usage: `mix nexus.verify`
  """
  use Mix.Task

  @preferred_cli_env :test

  # Rules from 09-nexus-coding-standards.md
  @forbidden_abbreviations ~r/(Exp|Trans|Cmd|Evt|Amt|Upd|Calc|Mgmt)([A-Z]|$)/

  def run(_args) do
    Mix.shell().info([:cyan, "Starting Nexus Architectural Audit (Phase 2 Hardening)..."])

    results = []

    # 1. Audit Messaging (Commands & Events)
    results = results ++ audit_messaging()

    # 2. Audit Projections (Nexus.Schema)
    results = results ++ audit_projections()

    # 3. Audit Projectors (Event Variable Naming)
    results = results ++ audit_projectors()

    # 4. Global Audit (Moduledoc, Naming, Tensors, Purity)
    results = results ++ audit_global_standards()

    failures = Enum.filter(results, fn {status, _} -> status == :fail end)
    final_report(results, failures)
  end

  defp audit_messaging do
    commands = Path.wildcard("lib/nexus/**/commands/*.ex")
    events = Path.wildcard("lib/nexus/**/events/*.ex")

    Enum.map(commands, &audit_message_file(&1, :command)) ++
      Enum.map(events, &audit_message_file(&1, :event))
  end

  defp audit_message_file(path, type) do
    content = File.read!(path)
    errors = []

    # Basic messaging rules
    errors =
      if String.contains?(content, "alias Nexus.Types"),
        do: errors,
        else: errors ++ ["Missing `alias Nexus.Types`"]

    errors =
      if String.contains?(content, "@type t :: %__MODULE__{"),
        do: errors,
        else: errors ++ ["Missing `@type t` definition"]

    errors =
      case type do
        :command ->
          e =
            if String.contains?(content, "@enforce_keys"),
              do: errors,
              else: errors ++ ["Missing `@enforce_keys`"]

          if String.contains?(content, "defstruct"), do: e, else: e ++ ["Missing `defstruct`"]

        :event ->
          e =
            if String.contains?(content, "@derive Jason.Encoder"),
              do: errors,
              else: errors ++ ["Missing `@derive Jason.Encoder`"]

          if String.contains?(content, "defstruct"), do: e, else: e ++ ["Missing `defstruct`"]
      end

    errors = check_order(content, type, errors)
    errors = check_id_types(content, errors)

    if errors == [], do: {:pass, path}, else: {:fail, {path, errors}}
  end

  defp audit_projections do
    Path.wildcard("lib/nexus/**/projections/*.ex")
    |> Enum.map(fn path ->
      content = File.read!(path)
      errors = []

      errors =
        if String.contains?(content, "use Nexus.Schema"),
          do: errors,
          else: errors ++ ["Must use `Nexus.Schema` (Rule 6)"]

      errors =
        if String.contains?(content, "field :org_id, :binary_id"),
          do: errors,
          else: errors ++ ["Missing explicit `field :org_id, :binary_id` (Rule 6)"]

      # Exemption for global market data (Rule 6.3)
      errors =
        if String.contains?(path, "market_tick.ex"),
          do:
            Enum.reject(errors, &(&1 == "Missing explicit `field :org_id, :binary_id` (Rule 6)")),
          else: errors

      # Item 6.2: No shadowed @primary_key
      errors =
        if String.contains?(content, "@primary_key") do
          errors ++
            [
              "Manual `@primary_key` override found. Projections MUST rely on `Nexus.Schema` (Rule 6)"
            ]
        else
          errors
        end

      if errors == [], do: {:pass, path}, else: {:fail, {path, errors}}
    end)
  end

  defp audit_projectors do
    Path.wildcard("lib/nexus/**/projectors/*.ex")
    |> Enum.map(fn path ->
      content = File.read!(path)

      errors =
        if String.contains?(content, "project(") and
             not Regex.match?(~r/project\(%[^%]+{}\s+=\s+event,/, content) do
          ["Projector must name the event variable explicitly as `event` (Rule 1.1)"]
        else
          []
        end

      {errors, path}
    end)
    |> Enum.map(fn
      {errs, path} when errs != [] -> {:fail, {path, errs}}
      {_, path} -> {:pass, path}
    end)
  end

  defp audit_global_standards do
    Path.wildcard("lib/nexus/**/*.ex")
    |> Enum.reject(&String.contains?(&1, "test/"))
    |> Enum.map(fn path ->
      content = File.read!(path)
      errors = []

      # Rule 8: Moduledoc
      errors =
        if String.contains?(content, "@moduledoc"),
          do: errors,
          else: errors ++ ["Missing `@moduledoc` (Rule 8)"]

      # Rule 1: Naming
      module_name = get_module_name(content)

      errors =
        if Regex.match?(@forbidden_abbreviations, module_name),
          do:
            errors ++ ["Module name '#{module_name}' contains forbidden abbreviations (Rule 1)"],
          else: errors

      # Rule 13: Tensor Naming (Suffix all tensors with _tensor)
      errors =
        if Regex.match?(~r/\b([a-z0-9_]+)\s+=\s+Nx\.tensor/, content) and
             not Regex.match?(~r/\b([a-z0-9_]+)_tensor\s+=\s+Nx\.tensor/, content) do
          errors ++
            ["Variable assigned from `Nx.tensor` must be suffixed with `_tensor` (Rule 13)"]
        else
          errors
        end

      # Rule 5: Side Effect Isolation (Purity)
      has_io = String.contains?(content, "Repo") or String.contains?(content, "Ecto")
      has_math = String.contains?(content, "Nx") or String.contains?(content, "Scholar")
      is_infra = String.contains?(path, "application.ex") or String.contains?(path, "aggregates/")

      errors =
        if has_io and has_math and not is_infra do
          errors ++
            [
              "Module mixes Data I/O (Repo) with Predictive Math (Nx/Scholar). Isolate business logic (Rule 5)"
            ]
        else
          errors
        end

      # Rule 8.2: Mandatory @spec for all public functions
      # Find all public def matches
      public_defs =
        Regex.scan(~r/^\s*def\s+([a-z0-9_!\?]+)\(/m, content) |> Enum.map(&List.last/1)

      # Find all @spec matches
      specs = Regex.scan(~r/^\s*@spec\s+([a-z0-9_!\?]+)\(/m, content) |> Enum.map(&List.last/1)

      missing_specs = Enum.reject(public_defs, fn name -> name in specs end)

      errors =
        if missing_specs != [] and not String.contains?(path, "test/"),
          do:
            errors ++
              ["Missing `@spec` for public functions: #{Enum.join(missing_specs, ", ")} (Rule 8)"],
          else: errors

      # Rule 14: Type Alignment in function signatures
      if String.contains?(path, "services/") do
        # Check for arguments named org_id or user_id that aren't preceded by Types. or similar
        # def some_func(org_id, ...)
        if Regex.match?(~r/def\s+\w+\(([^)]*\s+)?(org_id|user_id|invoice_id)(\s+|,|\))/, content) do
          # Check if there is NO @spec mentioning Types for these
          if not String.contains?(content, "@spec") or not String.contains?(content, "Types.") do
            errors =
              errors ++
                ["Function signature uses primitive ID naming without Types alignment (Rule 14)"]

            errors
          else
            errors
          end
        else
          errors
        end
      else
        errors
      end

      if errors == [], do: {:pass, path}, else: {:fail, {path, errors}}
    end)
  end

  defp get_module_name(content) do
    case Regex.run(~r/defmodule\s+([A-Za-z0-9\.]+)\s+do/, content) do
      [_, name] -> name
      _ -> ""
    end
  end

  defp check_order(content, :command, errors) do
    alias_pos = get_pos(content, "alias Nexus.Types")
    type_pos = get_pos(content, "@type t")
    enforce_pos = get_pos(content, "@enforce_keys")
    struct_pos = get_pos(content, "defstruct")

    if alias_pos != -1 and type_pos != -1 and enforce_pos != -1 and struct_pos != -1 and
         alias_pos < type_pos and type_pos < enforce_pos and enforce_pos < struct_pos do
      errors
    else
      if alias_pos == -1 or type_pos == -1 or enforce_pos == -1 or struct_pos == -1,
        do: errors,
        else:
          errors ++
            ["Incorrect block order. Expected: alias -> @type t -> @enforce_keys -> defstruct"]
    end
  end

  defp check_order(content, :event, errors) do
    alias_pos = get_pos(content, "alias Nexus.Types")
    derive_pos = get_pos(content, "@derive Jason.Encoder")
    type_pos = get_pos(content, "@type t")
    struct_pos = get_pos(content, "defstruct")

    if alias_pos != -1 and derive_pos != -1 and type_pos != -1 and struct_pos != -1 and
         alias_pos < derive_pos and derive_pos < type_pos and type_pos < struct_pos do
      errors
    else
      if alias_pos == -1 or derive_pos == -1 or type_pos == -1 or struct_pos == -1,
        do: errors,
        else:
          errors ++ ["Incorrect block order. Expected: alias -> @derive -> @type t -> defstruct"]
    end
  end

  defp get_pos(content, pattern) do
    case :binary.match(content, pattern) do
      {pos, _len} -> pos
      :nomatch -> -1
    end
  end

  defp check_id_types(content, errors) do
    no_comments = String.replace(content, ~r/#.*$/, "", global: true, multiline: true)
    bad_line = Regex.run(~r/\w+_id:\s+(?!Types\.)[A-Za-z0-9\.]+/, no_comments)

    if bad_line,
      do: errors ++ ["ID field found without `Types.` prefix: #{Enum.at(bad_line, 0)}"],
      else: errors
  end

  defp final_report(results, failures) do
    total = length(results)
    passed = total - length(failures)

    Mix.shell().info([:bright, "\n--- Nexus Phase 2 Hardening Audit ---"])
    Mix.shell().info("Total Rules Checked: #{total}")
    Mix.shell().info([:green, "Passes: #{passed}"])

    Mix.shell().info([
      if(failures == [], do: :green, else: :red),
      "Violations: #{length(failures)}"
    ])

    if failures != [] do
      Mix.shell().info([:red, :bright, "\nViolations List:"])

      Enum.each(failures, fn {:fail, {path, errs}} ->
        Mix.shell().info([:yellow, "\n#{path}:"])
        Enum.each(errs, &Mix.shell().info("  - #{&1}"))
      end)

      System.halt(1)
    else
      Mix.shell().info([
        :green,
        :bright,
        "\n✨ Codebase is 100% compliant with Phase 2 Hardening!"
      ])
    end
  end
end
