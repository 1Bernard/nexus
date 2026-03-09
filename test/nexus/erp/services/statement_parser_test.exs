defmodule Nexus.ERP.Services.StatementParserTest do
  use ExUnit.Case, async: true
  alias Nexus.ERP.Services.StatementParser

  describe "parse/2 csv" do
    test "parses bank detail format (Date, Description, Debit, Credit, Balance)" do
      csv = """
      Date,Description,Debit,Credit,Balance
      2026-03-01,Salary credit,,5000.00,5000.00
      2026-03-02,ATM withdrawal,200.00,,4800.00
      2026-03-03,POS purchase,50.75,,4749.25
      """

      assert {:ok, lines} = StatementParser.parse("csv", csv)
      assert length(lines) == 3

      [l1, l2, l3] = lines
      assert l1.narrative == "Salary credit"
      assert Decimal.eq?(l1.amount, Decimal.new("5000.00"))

      assert l2.narrative == "ATM withdrawal"
      assert Decimal.eq?(l2.amount, Decimal.new("-200.00"))

      assert l3.narrative == "POS purchase"
      assert Decimal.eq?(l3.amount, Decimal.new("-50.75"))
    end

    test "parses elite fintech ledger format (20 columns)" do
      csv = """
      ledger_entry_id,ledger_group,trade_id,account_id,account_currency,timestamp,base_currency,quote_currency,mid_market_rate,customer_rate,spread,base_amount,quote_amount,fee_amount,liquidity_provider,execution_channel,debit_account_currency,credit_account_currency,running_balance,status
      LED10001,GRP9001,TRD5001,WALLET_USD_001,USD,2026-01-01T09:00:00,EUR,USD,1.084200,1.086000,0.001800,1200,1303.20,4.50,LP_CITI,MOBILE_APP,1307.70,,8692.30,SETTLED
      LED10002,GRP9001,TRD5001,WALLET_EUR_002,EUR,2026-01-01T09:00:00,EUR,USD,1.084200,1.086000,0.001800,1200,1303.20,4.50,LP_CITI,MOBILE_APP,,1195.50,11195.50,SETTLED
      """

      assert {:ok, lines} = StatementParser.parse("csv", csv)
      assert length(lines) == 2

      [l1, l2] = lines
      assert l1.ref == "LED10001"
      assert l1.currency == "USD"
      assert Decimal.eq?(l1.amount, Decimal.new("-1307.70"))
      assert l1.metadata["liquidity_provider"] == "LP_CITI"
      assert l1.metadata["spread"] == "0.001800"

      assert l2.ref == "LED10002"
      assert l2.currency == "EUR"
      assert Decimal.eq?(l2.amount, Decimal.new("1195.50"))
    end

    test "parses fintech ledger with UTF-8 BOM and leading empty lines" do
      csv =
        "\uFEFF\n\nledger_entry_id,ledger_group,trade_id,account_id,account_currency,timestamp,base_currency,quote_currency,mid_market_rate,customer_rate,spread,base_amount,quote_amount,fee_amount,liquidity_provider,execution_channel,debit_account_currency,credit_account_currency,running_balance,status\nLED10001,GRP9001,TRD5001,WALLET_USD_001,USD,2026-01-01T09:00:00,EUR,USD,1.084200,1.086000,0.001800,1200,1303.20,4.50,LP_CITI,MOBILE_APP,1307.70,,8692.30,SETTLED"

      assert {:ok, [l1]} = StatementParser.parse("csv", csv)
      assert l1.ref == "LED10001"
    end

    test "parses fintech ledger with trailing extra columns" do
      csv =
        "ledger_entry_id,ledger_group,trade_id,account_id,account_currency,timestamp,base_currency,quote_currency,mid_market_rate,customer_rate,spread,base_amount,quote_amount,fee_amount,liquidity_provider,execution_channel,debit_account_currency,credit_account_currency,running_balance,status,extra_column\nLED10001,GRP9001,TRD5001,WALLET_USD_001,USD,2026-01-01T09:00:00,EUR,USD,1.084200,1.086000,0.001800,1200,1303.20,4.50,LP_CITI,MOBILE_APP,1307.70,,8692.30,SETTLED,FOO"

      assert {:ok, [l1]} = StatementParser.parse("csv", csv)
      assert l1.ref == "LED10001"
    end
  end
end
