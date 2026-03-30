defmodule Nexus.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Nexus.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Nexus.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Nexus.DataCase
    end
  end

  setup tags do
    alias Ecto.Adapters.SQL.Sandbox
    Nexus.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.

  By default, starts a Sandbox owner so all DB writes are rolled back after
  each test. For feature tests that start projectors via `start_supervised!`,
  the projector writes would be included in this rollback and never visible.

  Tag a test with `@tag no_sandbox: true` to skip the Sandbox owner. The
  test is then responsible for cleaning up with `Repo.delete_all` in setup.
  """
  def setup_sandbox(tags) do
    alias Ecto.Adapters.SQL.Sandbox

    if tags[:no_sandbox] do
      # Auto mode: any process can checkout its own connection from the pool.
      # Commits are immediate. Test must clean up manually.
      Ecto.Adapters.SQL.Sandbox.mode(Nexus.Repo, :auto)
      :ok
    else
      pid = Sandbox.start_owner!(Nexus.Repo, shared: not tags[:async])
      on_exit(fn -> Sandbox.stop_owner(pid) end)
    end
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @doc """
  Runs a function without the SQL sandbox.
  Useful for tests that start background processes (like projectors) which
  need to write to the same database.
  """
  def unboxed_run(fun) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fun)
  end
end
