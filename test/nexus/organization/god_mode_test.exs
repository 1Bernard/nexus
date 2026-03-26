defmodule Nexus.Organization.GodModeTest do
  use Nexus.DataCase

  alias Nexus.Organization.Events.TenantSuspended
  alias Nexus.Organization.Events.TenantModuleToggled
  alias Nexus.Organization.Projectors.TenantProjector
  alias Nexus.Organization.Projections.Tenant
  alias Nexus.Repo

  setup do
    # Clear the projection versions table to ensure clean state
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Nexus.Repo.delete_all(Nexus.Organization.Projections.Tenant)

      Ecto.Adapters.SQL.query!(
        Nexus.Repo,
        "DELETE FROM projection_versions WHERE projection_name = 'Organization.TenantProjector'"
      )
    end)

    org_id = Nexus.Schema.generate_uuidv7()

    # Provision a tenant first
    tenant =
      %Tenant{
        id: org_id,
        org_id: org_id,
        name: "Nexus Corporation",
        status: "active",
        initial_admin_email: "admin@nexus.corp"
      }
      |> Repo.insert!()

    {:ok, %{org_id: org_id, tenant: tenant}}
  end

  describe "TenantProjector God-Mode Events" do
    test "projects TenantSuspended correctly", %{org_id: org_id} do
      event = %TenantSuspended{
        org_id: org_id,
        suspended_by: "system_admin",
        reason: "Test suspension",
        suspended_at: DateTime.utc_now()
      }

      :ok =
        TenantProjector.handle(event, %{
          handler_name: "Organization.TenantProjector",
          event_number: 1
        })

      projected = Repo.get_by(Tenant, org_id: org_id)
      assert projected.status == "SUSPENDED"
      assert projected.suspended_at != nil
    end

    test "projects TenantModuleToggled correctly", %{org_id: org_id} do
      # Enable a module
      event_enable = %TenantModuleToggled{
        org_id: org_id,
        module_name: "forecasting",
        enabled: true,
        toggled_by: "system_admin",
        toggled_at: DateTime.utc_now()
      }

      :ok =
        TenantProjector.handle(event_enable, %{
          handler_name: "Organization.TenantProjector",
          event_number: 2
        })

      projected = Repo.get_by(Tenant, org_id: org_id)
      assert "forecasting" in projected.modules_enabled

      # Disable it
      event_disable = %TenantModuleToggled{
        org_id: org_id,
        module_name: "forecasting",
        enabled: false,
        toggled_by: "system_admin",
        toggled_at: DateTime.utc_now()
      }

      :ok =
        TenantProjector.handle(event_disable, %{
          handler_name: "Organization.TenantProjector",
          event_number: 3
        })

      projected = Repo.get_by(Tenant, org_id: org_id)
      refute "forecasting" in projected.modules_enabled
    end
  end
end
