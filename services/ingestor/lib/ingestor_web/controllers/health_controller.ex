defmodule IngestorWeb.HealthController do
  @moduledoc """
  Liveness check for Docker and monitoring. It does not call the facade: answering means the
  HTTP layer is up, and there is no business rule involved.
  """

  use IngestorWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
