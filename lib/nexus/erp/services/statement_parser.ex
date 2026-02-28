defmodule Nexus.ERP.Services.StatementParser do
  @moduledoc """
  Pure Elixir parser for bank statement formats.
  Supports MT940 SWIFT and CSV (date, ref, amount, currency, narrative).
  """

  NimbleCSV.define(Nexus.ERP.Services.StatementParser.CSV, separator: ",", escape: "\"")

  @type line :: %{
          date: String.t(),
          ref: String.t(),
          amount: Decimal.t(),
          currency: String.t(),
          narrative: String.t()
        }

  @spec parse(String.t(), String.t()) :: {:ok, [line()]} | {:error, String.t()}
  def parse("mt940", content) when is_binary(content) and byte_size(content) > 0 do
    parse_mt940(content)
  end

  def parse("csv", content) when is_binary(content) and byte_size(content) > 0 do
    parse_csv(content)
  end

  def parse(_format, content) when byte_size(content) == 0 do
    {:error, "File content is empty"}
  end

  def parse(format, _content) do
    {:error, "Unsupported format: #{format}. Supported: mt940, csv"}
  end

  # ---------------------------------------------------------------------------
  # MT940 SWIFT Parser
  # ---------------------------------------------------------------------------
  # MT940 tags:
  #   :20:  — Transaction Reference Number
  #   :25:  — Account Identification
  #   :28C: — Statement Number
  #   :60F: — Opening Balance (F=Final) — currency is chars 4-6
  #   :61:  — Statement Line (transaction)
  #           Format: YYMMDD[MMDD]C/D[R]<amount>N<ref>\n<narrative>
  #   :86:  — Information to Account Owner (narrative for preceding :61:)
  # ---------------------------------------------------------------------------

  defp parse_mt940(content) do
    lines = String.split(content, ~r/\r?\n/)
    currency = extract_mt940_currency(lines)

    transactions =
      lines
      |> Enum.chunk_while(
        [],
        fn line, acc ->
          if String.starts_with?(line, ":61:") do
            {:cont, Enum.reverse(acc), [line]}
          else
            {:cont, [line | acc]}
          end
        end,
        fn acc -> {:cont, Enum.reverse(acc), []} end
      )
      |> Enum.reject(&Enum.empty?/1)
      |> Enum.filter(&Enum.any?(&1, fn l -> String.starts_with?(l, ":61:") end))
      |> Enum.map(&parse_mt940_block(&1, currency))
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(transactions) do
      {:error, "No transaction lines (:61:) found in MT940 file"}
    else
      {:ok, transactions}
    end
  end

  defp extract_mt940_currency(lines) do
    Enum.find_value(lines, "EUR", fn line ->
      if String.starts_with?(line, ":60F:") or String.starts_with?(line, ":60M:") do
        # :60F:C230101EUR1234,56 — currency starts at position 8 (after debit/credit + date)
        case Regex.run(~r/:60[FM]:[CD]R?\d{6}([A-Z]{3})/, line) do
          [_, currency] -> currency
          _ -> nil
        end
      end
    end)
  end

  defp parse_mt940_block(block, currency) do
    tag61 = Enum.find(block, &String.starts_with?(&1, ":61:"))
    tag86 = Enum.find(block, &String.starts_with?(&1, ":86:"))

    with tag61 when not is_nil(tag61) <- tag61,
         {:ok, date, amount, ref} <- parse_tag61(tag61) do
      narrative =
        if tag86,
          do: String.trim(String.replace_prefix(tag86, ":86:", "")),
          else: ref

      %{
        date: date,
        ref: ref,
        amount: amount,
        currency: currency,
        narrative: narrative
      }
    else
      _ -> nil
    end
  end

  # :61: YYMMDD[MMDD]C/D[R]<amount>N<ref>
  # Example: :61:2301030103CR1234,56NTRFBACS-REF-001
  defp parse_tag61(tag) do
    content = String.replace_prefix(tag, ":61:", "")

    case Regex.run(
           ~r/^(\d{6})(?:\d{4})?([CD]R?)([0-9]+,[0-9]*)N(.+)$/,
           String.trim(content)
         ) do
      [_, date_str, cd, amount_str, ref] ->
        amount = parse_amount(amount_str, cd)
        {:ok, format_mt940_date(date_str), amount, String.trim(ref)}

      _ ->
        :error
    end
  end

  defp format_mt940_date(<<yy::binary-size(2), mm::binary-size(2), dd::binary-size(2)>>) do
    "20#{yy}-#{mm}-#{dd}"
  end

  defp format_mt940_date(str), do: str

  defp parse_amount(str, cd) do
    normalised = String.replace(str, ",", ".")
    decimal = Decimal.new(normalised)
    if String.starts_with?(cd, "D"), do: Decimal.negate(decimal), else: decimal
  end

  # ---------------------------------------------------------------------------
  # CSV Parser
  # ---------------------------------------------------------------------------
  # Expected header: date,ref,amount,currency,narrative
  # ---------------------------------------------------------------------------

  defp parse_csv(content) do
    alias Nexus.ERP.Services.StatementParser.CSV

    rows =
      content
      |> CSV.parse_string(skip_headers: true)
      |> Enum.map(&parse_csv_row/1)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(rows) do
      {:error, "CSV has no valid data rows"}
    else
      {:ok, rows}
    end
  rescue
    e -> {:error, "CSV parse error: #{Exception.message(e)}"}
  end

  defp parse_csv_row([date, ref, amount_str, currency, narrative]) do
    case Decimal.parse(String.trim(amount_str)) do
      {decimal, ""} ->
        %{
          date: String.trim(date),
          ref: String.trim(ref),
          amount: decimal,
          currency: String.trim(currency),
          narrative: String.trim(narrative)
        }

      _ ->
        nil
    end
  end

  defp parse_csv_row(_), do: nil
end
