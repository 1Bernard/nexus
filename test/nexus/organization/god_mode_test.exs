defmodule Nexus.Organization.GodModeTest do
  @moduledoc """
  Elite BDD tests for Organization God-Mode actions.
  """
  use Cabbage.Feature, file: "organization/tenant_god_mode.feature"
  use Nexus.DataCase

  alias Nexus.Organization.Events.{TenantSuspended, TenantModuleToggled}
  alias Nexus.Organization.Projectors.TenantProjector
  alias Nexus.Organization.Projections.Tenant

  @moduletag :no_sandbox

  setup do
    unboxed_run(fn ->
      Repo.delete_all(Tenant)

      Ecto.Adapters.SQL.query!(
        Repo,
        "DELETE FROM projection_versions WHERE projection_name = 'Organization.TenantProjector'"
      )
    end)

    :ok
  end

  defgiven ~r/^an active tenant "(?<name>[^"]+)" exists$/, %{name: name}, _state do
    org_id = Nexus.Schema.generate_uuidv7()

    unboxed_run(fn ->
      %Tenant{
        id: org_id,
        org_id: org_id,
        name: name,
        status: "active",
        initial_admin_email: "admin@nexus.corp"
      }
      |> Repo.insert!()
    end)

    {:ok, %{org_id: org_id}}
  end

  defwhen ~r/^the system administrator suspends the tenant for "(?<reason>[^"]+)"$/,
          %{reason: reason},
          %{org_id: org_id} do
    event = %TenantSuspended{
      org_id: org_id,
      suspended_by: "system_admin",
      reason: reason,
      suspended_at: DateTime.utc_now()
    }

    unboxed_run(fn ->
      :ok =
        TenantProjector.handle(event, %{
          handler_name: "Organization.TenantProjector",
          event_number: 1
        })
    end)

    :ok
  end

  defwhen ~r/^the "(?<module>[^"]+)" module is (?<action>enabled|disabled) for the tenant$/,
          %{module: module_name, action: action},
          %{org_id: org_id} do
    enabled = action == "enabled"

    event = %TenantModuleToggled{
      org_id: org_id,
      module_name: module_name,
      enabled: enabled,
      toggled_by: "system_admin",
      toggled_at: DateTime.utc_now()
    }

    unboxed_run(fn ->
      :ok =
        TenantProjector.handle(event, %{
          handler_name: "Organization.TenantProjector",
          event_number: if(enabled, do: 2, else: 3)
        })
    end)

    :ok
  end

  defthen ~r/^the tenant status should be "(?<status>[^"]+)"$/, %{status: status}, %{org_id: org_id} do
    projected = unboxed_run(fn -> Repo.get!(Tenant, org_id) end)
    assert projected.status == status
    :ok
  end

  defthen ~r/^the "(?<module>[^"]+)" module should be (?<state>active|inactive) in the read model$/,
          %{module: module_name, state: state},
          %{org_id: org_id} do
    projected = unboxed_run(fn -> Repo.get!(Tenant, org_id) end)

    if state == "active" do
      assert module_name in projected.modules_enabled
    else
      refute module_name in projected.modules_enabled
    end

    :ok
  end
end
