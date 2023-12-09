defmodule Demux.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    flame_parent = FLAME.Parent.get()

    children =
      [
        DemuxWeb.Telemetry,
        Demux.Repo,
        !flame_parent &&
          {DNSCluster, query: Application.get_env(:demux, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Demux.PubSub},
        # Start the Finch HTTP client for sending emails
        !flame_parent &&
          {Finch, name: Demux.Finch},
        # Start a worker by calling: Demux.Worker.start_link(arg)
        # {Demux.Worker, arg},
        # Start to serve requests, typically the last entry
        {FLAME.Pool,
         name: Demux.FFMpegRunner,
         min: 0,
         max: 10,
         max_concurrency: 5,
         idle_shutdown_after: 10_000,
         log: :debug},
        !flame_parent && DemuxWeb.Endpoint
      ]
      |> Enum.filter(& &1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Demux.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DemuxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
