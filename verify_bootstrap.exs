# verify_bootstrap.exs
Mix.Task.run("app.start")

IO.puts("Waiting for projectors to catch up...")
Process.sleep(5000)

tenants = Nexus.Repo.all(Nexus.Organization.Projections.Tenant)
users = Nexus.Repo.all(Nexus.Identity.Projections.User)

IO.puts("\n--- TENANTS ---")
Enum.each(tenants, fn t -> IO.inspect(t) end)

IO.puts("\n--- USERS ---")
Enum.each(users, fn u -> IO.inspect(u) end)

if Enum.any?(tenants, &(&1.name == "Nexus Platform")) do
  IO.puts("\n✅ Root Organization found.")
else
  IO.puts("\n❌ Root Organization NOT found.")
end

if Enum.any?(users, &(&1.role == "system_admin")) do
  IO.puts("✅ System Admin found.")
else
  IO.puts("❌ System Admin NOT found.")
end
