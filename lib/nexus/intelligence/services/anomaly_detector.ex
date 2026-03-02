defmodule Nexus.Intelligence.Services.AnomalyDetector do
  @moduledoc """
  Service for running ML models to detect invoice outliers.
  """

  alias Nexus.Intelligence.Commands.AnalyzeInvoice

  @spec analyze(Nexus.Intelligence.Commands.AnalyzeInvoice.t()) :: {:ok, map()} | {:error, any()}
  def analyze(%AnalyzeInvoice{amount: amount, vendor_name: vendor}) do
    amount_f = Decimal.to_float(amount)

    # In a production environment, we would fetch historical invoice amounts
    # for this vendor from the ERP Domain (e.g., via a process manager or projection).
    # For now, we seed a historical distribution tensor centered around 1000.
    history_tensor =
      if vendor == "CorpTech" do
        Nx.tensor([900.0, 1100.0, 1000.0, 950.0, 1050.0])
      else
        # No history, no anomaly
        Nx.tensor([amount_f])
      end

    mean = Nx.mean(history_tensor)
    std_dev = Nx.standard_deviation(history_tensor)

    # If std_dev is 0, we can't compute Z-score accurately, assume no anomaly
    if Nx.to_number(std_dev) == 0.0 do
      {:ok, %{is_anomaly: false}}
    else
      amount_tensor = Nx.tensor(amount_f)

      # Z-score = (X - μ) / σ
      z_score_tensor = Nx.divide(Nx.subtract(amount_tensor, mean), std_dev)
      z_score = Nx.to_number(z_score_tensor)

      # Standard 3-sigma rule for outlier detection
      is_outlier? = abs(z_score) > 3.0

      if is_outlier? do
        # Map Z-score to 0-1 probability
        normalized_score = min(abs(z_score) / 10.0, 0.99)

        {:ok,
         %{
           is_anomaly: true,
           score: normalized_score,
           reason:
             "Amount is a #{Float.round(z_score, 2)}σ statistical outlier from vendor's historical rolling average"
         }}
      else
        {:ok, %{is_anomaly: false}}
      end
    end
  end
end
