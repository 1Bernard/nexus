ExUnit.start()
Application.ensure_all_started(:nexus)
Ecto.Adapters.SQL.Sandbox.mode(Nexus.Repo, :manual)
