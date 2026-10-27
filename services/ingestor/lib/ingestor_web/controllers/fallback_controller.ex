defmodule IngestorWeb.FallbackController do
  @moduledoc """
  Turns the `{:error, type, detail}` returned by a controller action into an HTTP response.

  Invalid input is the caller's fault (422, with the error of each field). Any other error is
  ours (500): its detail is logged, never sent, so database messages do not leak to clients.
  """

  use IngestorWeb, :controller

  require Logger

  def call(conn, {:error, :invalid_input, changeset}) do
    conn
    |> put_status(:unprocessable_content)
    |> put_view(json: IngestorWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, type, detail}) do
    Logger.error("#{inspect(type)}: #{inspect(detail)}")

    conn
    |> put_status(:internal_server_error)
    |> put_view(json: IngestorWeb.ErrorJSON)
    |> render(:"500")
  end
end
