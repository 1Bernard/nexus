defmodule Nexus.Router do
  @moduledoc """
  The Commanded Router for the Nexus application.
  Dispatches commands to the appropriate domain aggregates.
  """
  use Commanded.Commands.Router

  # --- Identity Domain ---
  dispatch(Nexus.Identity.Commands.RegisterUser,
    to: Nexus.Identity.Aggregates.User,
    identity: :user_id
  )

  dispatch(Nexus.Identity.Commands.VerifyBiometric,
    to: Nexus.Identity.Aggregates.User,
    identity: :user_id
  )
end
