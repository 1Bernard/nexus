defmodule Mix.Tasks.Nexus.BootstrapRootAdmin do
  @moduledoc """
  Seed task to initialize the Nexus Platform with a Root Organization and System Admin.
  """
  use Mix.Task
  require Logger

  alias Nexus.Organization.Commands.ProvisionTenant
  alias Nexus.Identity.Commands.RegisterSystemAdmin

  @impl Mix.Task
  def run(_args) do
    # Ensure the app and its dependencies are started
    Mix.Task.run("app.start")

    Logger.info("[Bootstrap] Initializing Nexus Root Infrastructure...")

    # Predictable UUID for root
    root_org_id = "00000000-0000-0000-0000-000000000000"
    admin_id = Nexus.Schema.generate_uuidv7()
    admin_email = "admin@nexus-platform.io"

    # 1. Provision Root Organization
    provision_cmd = %ProvisionTenant{
      org_id: root_org_id,
      name: "Nexus Platform",
      initial_admin_email: admin_email,
      provisioned_by: "system_bootstrap"
    }

    case Nexus.App.dispatch(provision_cmd) do
      :ok ->
        Logger.info("[Bootstrap] Root Organization '#{provision_cmd.name}' provisioned.")
        # 2. Register System Admin
        register_cmd = %RegisterSystemAdmin{
          user_id: admin_id,
          org_id: root_org_id,
          email: admin_email,
          display_name: "Master Admin"
        }

        case Nexus.App.dispatch(register_cmd) do
          :ok ->
            Logger.info("[Bootstrap] System Admin '#{register_cmd.display_name}' created.")
            Logger.info("[Bootstrap] Credentials: #{admin_email} (Passkey Recovery Required)")
            Logger.info("[Bootstrap] Done.")

          {:error, reason} ->
            Logger.error("[Bootstrap] Failed to create System Admin: #{inspect(reason)}")
        end

      {:error, :already_provisioned} ->
        Logger.info("[Bootstrap] Root Organization already exists. Skipping.")

      {:error, reason} ->
        Logger.error("[Bootstrap] Failed to provision Root Organization: #{inspect(reason)}")
    end
  end
end
