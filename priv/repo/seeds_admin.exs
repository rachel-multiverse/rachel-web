# Admin user seed script
# Run with: mix run priv/repo/seeds_admin.exs

alias Rachel.Repo
alias Rachel.Accounts.User

IO.puts("Setting up admin user...")

# You can either:
# 1. Update an existing user by email
# 2. Create a new admin user

# Option 1: Update existing user to admin (uncomment and modify as needed)
# case Repo.get_by(User, email: "your-email@example.com") do
#   nil ->
#     IO.puts("User not found with that email")
#   user ->
#     user
#     |> Ecto.Changeset.change(is_admin: true)
#     |> Repo.update!()
#     IO.puts("✅ User #{user.email} is now an admin")
# end

# Option 2: Create a new admin user (uncomment and modify as needed)
# %User{}
# |> User.registration_changeset(%{
#   email: "admin@example.com",
#   password: "SecurePassword123!",
#   username: "admin",
#   display_name: "Administrator",
#   is_admin: true
# })
# |> Repo.insert!()
# |> IO.inspect(label: "Created admin user")

IO.puts("""

To make a user an admin:
1. Either uncomment and modify one of the options above, or
2. Run this in iex -S mix:

   alias Rachel.{Repo, Accounts.User}
   user = Repo.get_by(User, email: "your-email@example.com")
   user |> Ecto.Changeset.change(is_admin: true) |> Repo.update!()
""")
