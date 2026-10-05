defmodule Ingestor.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Ingestor.Worker.start_link(arg)
      # {Ingestor.Worker, arg}
    ]

    opts = [strategy: :one_for_one, name: Ingestor.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
