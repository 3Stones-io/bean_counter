import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/bean_counter start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :bean_counter, BeanCounterWeb.Endpoint, server: true
end

if config_env() in [:dev, :prod] do
  # GitHub configuration for all environments
  github_app_id =
    System.get_env("GITHUB_APP_ID") ||
      raise """
      environment variable GITHUB_APP_ID is missing.
      """

  github_end_date_field_id =
    System.get_env("GITHUB_END_DATE_FIELD_ID") ||
      raise """
      environment variable GITHUB_END_DATE_FIELD_ID is missing.
      """

  github_installation_id =
    System.get_env("GITHUB_INSTALLATION_ID") ||
      raise """
      environment variable GITHUB_INSTALLATION_ID is missing.
      """

  github_org =
    System.get_env("GITHUB_ORG") ||
      raise """
      environment variable GITHUB_ORG is missing.
      """

  github_private_key =
    System.get_env("GITHUB_PRIVATE_KEY") ||
      raise """
      environment variable GITHUB_PRIVATE_KEY is missing.
      """

  github_project_id =
    System.get_env("GITHUB_PROJECT_ID") ||
      raise """
      environment variable GITHUB_PROJECT_ID is missing.
      """

  github_repo =
    System.get_env("GITHUB_REPO") ||
      raise """
      environment variable GITHUB_REPO is missing.
      """

  github_start_date_field_id =
    System.get_env("GITHUB_START_DATE_FIELD_ID") ||
      raise """
      environment variable GITHUB_START_DATE_FIELD_ID is missing.
      """

  github_status_field_id =
    System.get_env("GITHUB_STATUS_FIELD_ID") ||
      raise """
      environment variable GITHUB_STATUS_FIELD_ID is missing.
      """

  github_status_in_progress =
    System.get_env("GITHUB_STATUS_IN_PROGRESS") ||
      raise """
      environment variable GITHUB_STATUS_IN_PROGRESS is missing.
      """

  github_status_in_review =
    System.get_env("GITHUB_STATUS_IN_REVIEW") ||
      raise """
      environment variable GITHUB_STATUS_IN_REVIEW is missing.
      """

  github_webhook_secret =
    System.get_env("GITHUB_WEBHOOK_SECRET") ||
      raise """
      environment variable GITHUB_WEBHOOK_SECRET is missing.
      """

  config :bean_counter, :github,
    app_id: github_app_id,
    end_date_field_id: github_end_date_field_id,
    installation_id: github_installation_id,
    org: github_org,
    private_key: github_private_key,
    project_id: github_project_id,
    repo: github_repo,
    start_date_field_id: github_start_date_field_id,
    status_field_id: github_status_field_id,
    status_in_progress: github_status_in_progress,
    status_in_review: github_status_in_review,
    webhook_secret: github_webhook_secret
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :bean_counter, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :bean_counter, BeanCounterWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :bean_counter, BeanCounterWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :bean_counter, BeanCounterWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
