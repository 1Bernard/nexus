org_id = Uniq.UUID.uuid7()
user_id = Uniq.UUID.uuid7()

:ok = Nexus.App.dispatch(%Nexus.Organization.Commands.ProvisionTenant{
  org_id: org_id,
  name: "Nexus Corporation",
  initial_admin_email: "admin@nexus.app",
  provisioned_by: user_id
})

:ok = Nexus.App.dispatch(%Nexus.Identity.Commands.RegisterSystemAdmin{
  user_id: user_id,
  org_id: org_id,
  email: "admin@nexus.app",
  display_name: "Root Admin"
})

IO.puts "Admin seeded: #{user_id}"
