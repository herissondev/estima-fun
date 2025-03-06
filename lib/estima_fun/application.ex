defmodule EstimaFun.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EstimaFunWeb.Telemetry,
      EstimaFun.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:estima_fun, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:estima_fun, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: EstimaFun.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: EstimaFun.Finch},
      # Start a worker by calling: EstimaFun.Worker.start_link(arg)
      # {EstimaFun.Worker, arg},
      {Registry, keys: :unique, name: EstimaFun.GameRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: EstimaFun.GameSupervisor},
      # Start to serve requests, typically the last entry
      EstimaFunWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EstimaFun.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EstimaFunWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") != nil
  end
end
