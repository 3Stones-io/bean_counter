defmodule BeanCounter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BeanCounterWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:bean_counter, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BeanCounter.PubSub},
      # Start a worker by calling: BeanCounter.Worker.start_link(arg)
      # {BeanCounter.Worker, arg},
      # Start to serve requests, typically the last entry
      BeanCounterWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BeanCounter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BeanCounterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
