import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :bean_counter, BeanCounterWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "0xlJ2L+oGdqmfawbL0tTJ/owssp0GHvAbK3Amj1uoYTBqZx/8qUaIUGMAzOYQXyy",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
