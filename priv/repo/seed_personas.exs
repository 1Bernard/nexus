# priv/repo/seed_personas.exs
alias Nexus.App
alias Nexus.Identity.Commands.RegisterUser
alias Nexus.Schema
alias Nexus.Repo
alias Nexus.Identity.Projections.User

# We unify all personas into the Global Org for dev-mode visibility in the same DataGrid
org_id = "00000000-0000-0000-0000-000000000000"

personas = [
  %{
    id: "019c9247-5ee0-7732-9423-5627160214ce", # Fixed ID for Consistency
    org_id: org_id,
    email: "admin@nexus-platform.io",
    display_name: "Master Admin",
    role: "system_admin"
  },
  %{
    id: Schema.generate_uuidv7(),
    org_id: org_id,
    email: "admin@nexus-corp.com",
    display_name: "Org Admin (Corp)",
    role: "admin"
  },
  %{
    id: Schema.generate_uuidv7(),
    org_id: org_id,
    email: "elena@global-corp.com",
    display_name: "Elena (Trader)",
    role: "trader"
  },
  %{
    id: Schema.generate_uuidv7(),
    org_id: org_id,
    email: "observer@nexus-platform.io",
    display_name: "Platform Auditor",
    role: "viewer"
  }
]

IO.puts("Synchronizing standard personas into Global Org...")

Enum.each(personas, fn p ->
  # 1. Look for existing user
  existing_user = Repo.get_by(User, email: p.email)

  if is_nil(existing_user) do
    # 2. Register new user
    cmd = %RegisterUser{
      user_id: p.id,
      org_id: p.org_id,
      email: p.email,
      display_name: p.display_name,
      role: p.role,
      cose_key: Base.encode64("bootstrap_cose_key"),
      credential_id: Base.encode64("bootstrap_credential_id"),
      registered_at: DateTime.utc_now()
    }

    case App.dispatch(cmd) do
      :ok -> IO.puts("Seeded new persona (\#{p.role}): \#{p.email}")
      {:error, reason} -> IO.puts("Failed to seed \#{p.email}: \#{inspect(reason)}")
    end
  else
    # 3. Synchronize Role & Org if needed
    # Note: org_id changes are rare and don't have a command in this POC, 
    # so we update the projection directly for dev-mode alignment.
    if existing_user.role != p.role or existing_user.org_id != p.org_id or existing_user.display_name != p.display_name do
      IO.puts("Updating existing persona \#{p.email}...")
      
      # We use Ecto directly to force-align projections in dev mode for Persona visibility
      existing_user
      |> Ecto.Changeset.change(role: p.role, org_id: p.org_id, display_name: p.display_name)
      |> Repo.update!()

      IO.puts("Successfully synchronized \#{p.email}")
    else
      IO.puts("Persona already correctly configured: \#{p.email}")
    end
  end
end)

IO.puts("Persona seeding complete.")
