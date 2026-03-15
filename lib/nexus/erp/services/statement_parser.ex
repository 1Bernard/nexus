defmodule Nexus.ERP.Services.StatementParser do
  @moduledoc """
  Pure Elixir parser for bank statement formats.
  Supports MT940 SWIFT and CSV (date, ref, amount, currency, narrative).
  """

  NimbleCSV.define(Nexus.ERP.Services.StatementParser.CSV, separator: ",", escape: "\"")
  NimbleCSV.define(Nexus.ERP.Services.StatementParser.SemiCSV, separator: ";", escape: "\"")

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

  defp format_mt940_date(string), do: string

  defp parse_amount(amount_string, credit_debit_indicator) do
    normalised = String.replace(amount_string, ",", ".")
    decimal = Decimal.new(normalised)

    if String.starts_with?(credit_debit_indicator, "D"),
      do: Decimal.negate(decimal),
      else: decimal
  end

  # ---------------------------------------------------------------------------
  # CSV Parser
  # ---------------------------------------------------------------------------
  # Expected header: date,ref,amount,currency,narrative
  # ---------------------------------------------------------------------------

  defp parse_csv(content) do
    # Strip BOM and leading/trailing whitespace/newlines
    content =
      content
      |> String.replace("\uFEFF", "")
      |> String.trim_leading()

    # Peek at headers — try both comma and semicolon
    {headers, delimiter} =
      case detect_headers(content) do
        {:ok, h, d} -> {h, d}
        _ -> {[], ","}
      end

    cond do
      # Elite Fintech Format: check if signature headers exist anywhere in the row
      "ledger_entry_id" in headers and "trade_id" in headers ->
        parse_fintech_ledger_csv(content, delimiter)

      # Global FX Format (16 cols): check for transaction_id
      "transaction_id" in headers and "account_currency" in headers ->
        parse_global_fx_csv(content, delimiter)

      # Fintech Industry Format (13 cols): check for transaction_id and account_number
      "transaction_id" in headers and "account_number" in headers ->
        parse_fintech_industry_csv(content, delimiter)

      # User format: Date, Description, Debit, Credit, Balance
      "date" in headers and "description" in headers and "debit" in headers ->
        parse_bank_detail_csv(content, delimiter)

      # Default format: date, ref, amount, currency, narrative
      "date" in headers and "ref" in headers and "amount" in headers ->
        parse_nexus_standard_csv(content, delimiter)

      true ->
        # Final fallback heuristic: try standard parsing
        parse_nexus_standard_csv(content, delimiter)
    end
  rescue
    e -> {:error, "CSV parse error: #{Exception.message(e)}"}
  end

  defp parse_nexus_standard_csv(content, delimiter) do
    parser = get_parser(delimiter)

    rows =
      content
      |> parser.parse_string(skip_headers: true)
      |> Enum.map(&parse_standard_row/1)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(rows), do: {:error, "No valid data rows in standard CSV"}, else: {:ok, rows}
  end

  defp parse_bank_detail_csv(content, delimiter) do
    parser = get_parser(delimiter)

    rows =
      content
      |> parser.parse_string(skip_headers: true)
      |> Enum.map(&parse_bank_row/1)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(rows), do: {:error, "No valid data rows in bank detail CSV"}, else: {:ok, rows}
  end

  defp parse_standard_row([date, ref, amount_string, currency, narrative]) do
    case Nexus.Schema.parse_decimal(amount_string) do
      decimal ->
        %{
          date: normalize_date(date),
          ref: String.trim(ref),
          amount: decimal,
          currency: String.trim(currency),
          narrative: String.trim(narrative)
        }
    end
  end

  defp parse_standard_row(_), do: nil

  defp parse_bank_row([date, narrative, debit_string, credit_string | _]) do
    debit = Nexus.Schema.parse_decimal_safe(debit_string)
    credit = Nexus.Schema.parse_decimal_safe(credit_string)

    # Net amount = Credit (positive) - Debit (positive value in debit column)
    # If debit column contains positive numbers, we subtract them.
    amount = Decimal.sub(credit, debit)

    if String.trim(date) != "" do
      %{
        date: normalize_date(date),
        ref: "",
        amount: amount,
        # Default to EUR for this format unless we find a way to detect it
        currency: "EUR",
        narrative: String.trim(narrative)
      }
    else
      nil
    end
  end

  defp parse_bank_row(_), do: nil

  defp parse_fintech_ledger_csv(content, delimiter) do
    parser = get_parser(delimiter)

    rows =
      content
      |> parser.parse_string(skip_headers: true)
      |> Enum.map(&parse_fintech_row/1)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(rows), do: {:error, "No valid data rows in fintech ledger"}, else: {:ok, rows}
  end

  defp parse_fintech_row(columns) when is_list(columns) and length(columns) >= 20 do
    [
      ledger_id,
      group,
      trade_id,
      account_id,
      acc_currency,
      timestamp,
      base_cur,
      quote_cur,
      mid_rate,
      cust_rate,
      spread,
      base_amt,
      quote_amt,
      fee,
      lp,
      channel,
      debit_string,
      credit_string,
      balance_string,
      status | _rest
    ] = columns

    debit = Nexus.Schema.parse_decimal_safe(debit_string)
    credit = Nexus.Schema.parse_decimal_safe(credit_string)
    amount = Decimal.sub(credit, debit)

    # Elite Metadata for auditing
    metadata = %{
      "ledger_entry_id" => ledger_id,
      "ledger_group" => group,
      "trade_id" => trade_id,
      "account_id" => account_id,
      "base_currency" => base_cur,
      "quote_currency" => quote_cur,
      "mid_market_rate" => mid_rate,
      "customer_rate" => cust_rate,
      "spread" => spread,
      "base_amount" => base_amt,
      "quote_amount" => quote_amt,
      "fee_amount" => fee,
      "liquidity_provider" => lp,
      "execution_channel" => channel,
      "running_balance" => balance_string,
      "status" => status
    }

    %{
      date: timestamp |> String.split("T") |> List.first() |> normalize_date(),
      ref: ledger_id,
      amount: amount,
      currency: String.trim(acc_currency),
      narrative: "#{channel} | #{lp} | Trade #{trade_id}",
      metadata: metadata
    }
  end

  defp parse_fintech_row(_), do: nil

  defp parse_global_fx_csv(content, delimiter) do
    parser = get_parser(delimiter)

    rows =
      content
      |> parser.parse_string(skip_headers: true)
      |> Enum.map(&parse_global_fx_row/1)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(rows), do: {:error, "No valid data rows in global FX"}, else: {:ok, rows}
  end

  defp parse_global_fx_row(columns) when is_list(columns) and length(columns) >= 16 do
    [
      tx_id,
      _acc_id,
      booking_date,
      _value_date,
      _tx_type,
      merchant,
      channel,
      reference,
      _tx_cur,
      _tx_amt,
      _fx_rate,
      acc_cur,
      debit_string,
      credit_string,
      balance_string,
      status | _rest
    ] = columns

    debit = Nexus.Schema.parse_decimal_safe(debit_string)
    credit = Nexus.Schema.parse_decimal_safe(credit_string)
    amount = Decimal.sub(credit, debit)

    %{
      date: normalize_date(booking_date),
      ref: String.trim(tx_id),
      amount: amount,
      currency: String.trim(acc_cur),
      narrative: "#{String.trim(merchant)} | #{String.trim(channel)} | #{String.trim(reference)}",
      metadata: %{
        "transaction_id" => tx_id,
        "running_balance" => balance_string,
        "status" => status
      }
    }
  end

  defp parse_global_fx_row(_), do: nil

  defp parse_fintech_industry_csv(content, delimiter) do
    parser = get_parser(delimiter)

    rows =
      content
      |> parser.parse_string(skip_headers: true)
      |> Enum.map(&parse_fintech_industry_row/1)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(rows),
      do: {:error, "No valid data rows in fintech industry CSV"},
      else: {:ok, rows}
  end

  defp parse_fintech_industry_row(columns) when is_list(columns) and length(columns) >= 13 do
    [
      tx_id,
      _acc_num,
      booking_date,
      _value_date,
      description,
      merchant,
      channel,
      reference,
      debit_string,
      credit_string,
      currency,
      balance_string,
      status | _rest
    ] = columns

    debit = Nexus.Schema.parse_decimal_safe(debit_string)
    credit = Nexus.Schema.parse_decimal_safe(credit_string)
    amount = Decimal.sub(credit, debit)

    %{
      date: normalize_date(booking_date),
      ref: String.trim(tx_id),
      amount: amount,
      currency: String.trim(currency),
      narrative:
        "#{String.trim(description)} | #{String.trim(merchant)} | #{String.trim(channel)} | #{String.trim(reference)}",
      metadata: %{
        "transaction_id" => tx_id,
        "running_balance" => balance_string,
        "status" => status
      }
    }
  end

  defp parse_fintech_industry_row(_), do: nil

  defp detect_headers(content) do
    first_line = content |> String.split("\n") |> List.first("")

    # Try comma
    headers_comma = parse_line(first_line, ",")
    # Try semicolon
    headers_semi = parse_line(first_line, ";")

    cond do
      "ledger_entry_id" in headers_comma or "trade_id" in headers_comma ->
        {:ok, headers_comma, ","}

      "ledger_entry_id" in headers_semi or "trade_id" in headers_semi ->
        {:ok, headers_semi, ";"}

      "transaction_id" in headers_comma and "account_currency" in headers_comma ->
        {:ok, headers_comma, ","}

      "transaction_id" in headers_semi and "account_currency" in headers_semi ->
        {:ok, headers_semi, ";"}

      "transaction_id" in headers_comma and "account_number" in headers_comma ->
        {:ok, headers_comma, ","}

      "transaction_id" in headers_semi and "account_number" in headers_semi ->
        {:ok, headers_semi, ";"}

      # Default to comma if no signature found
      true ->
        {:ok, headers_comma, ","}
    end
  end

  defp parse_line(line, delimiter) do
    parser = get_parser(delimiter)

    line
    |> parser.parse_string(skip_headers: false)
    |> Enum.at(0, [])
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.downcase/1)
  end

  defp get_parser(";"), do: Nexus.ERP.Services.StatementParser.SemiCSV
  defp get_parser(_), do: Nexus.ERP.Services.StatementParser.CSV

  defp normalize_date(date) do
    date = String.trim(date)

    case Regex.run(~r/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/, date) do
      [_, dd, mm, yyyy] ->
        yyyy <> "-" <> String.pad_leading(mm, 2, "0") <> "-" <> String.pad_leading(dd, 2, "0")

      _ ->
        date
    end
  end
end
