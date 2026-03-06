defmodule Nexus.Organization.Entitlement do
  @moduledoc """
  Central registry for feature entitlements across the platform.
  Defines which features are considered 'premium' and groups them by domain.
  """

  defstruct [:id, :name, :description, :category, :tier]

  @features [
    %{
      id: "forecasting",
      name: "Liquidity Forecasting",
      description: "AI-driven cash flow predictions and scenario modeling.",
      category: "Treasury",
      tier: :premium
    },
    %{
      id: "multi_currency",
      name: "Multi-Currency Support",
      description: "Manage exposure and spot rates across global entities.",
      category: "Treasury",
      tier: :core
    },
    %{
      id: "ai_sentinel",
      name: "AI Sentinel",
      description: "Anomaly detection and automated risk assessment.",
      category: "Intelligence",
      tier: :premium
    },
    %{
      id: "bulk_payments",
      name: "Bulk Payment Processing",
      description: "Execute large-scale domestic and international payments.",
      category: "Payments",
      tier: :core
    }
  ]

  @doc """
  Lists all available entitlements defined in the system.
  """
  def list_all, do: Enum.map(@features, &struct!(__MODULE__, &1))

  @doc """
  Groups entitlements by their domain category for better UI presentation.
  """
  def grouped_by_category do
    list_all() |> Enum.group_by(& &1.category)
  end

  @doc """
  Returns only premium-tier features.
  """
  def list_premium do
    Enum.filter(list_all(), &(&1.tier == :premium))
  end
end
