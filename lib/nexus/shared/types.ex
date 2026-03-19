defmodule Nexus.Types do
  @moduledoc """
  Centralized Type Definitions for Nexus.
  Provides a single source of truth for domain-specific types like Money,
  OrgId, and Currency.
  """

  @type money :: Decimal.t()
  @type org_id :: binary() | :all
  @type currency :: String.t()
  @type binary_id :: String.t()
  @type vault_id :: String.t()
  @type datetime :: DateTime.t()
end
