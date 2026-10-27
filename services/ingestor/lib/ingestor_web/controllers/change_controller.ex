defmodule IngestorWeb.ChangeController do
  @moduledoc """
  `GET /changes?cnpj=...&since=...`: the changes detected for a CNPJ.

  Only translates the request: string params become the facade's atom keys, unvalidated. A
  missing `cnpj` is passed as `nil` so the pipeline answers it like any other invalid input.
  Errors go to `IngestorWeb.FallbackController`.
  """

  use IngestorWeb, :controller

  action_fallback IngestorWeb.FallbackController

  def index(conn, params) do
    with {:ok, %{changes: changes}} <-
           Ingestor.list_changes(%{cnpj: params["cnpj"], since: params["since"]}) do
      render(conn, :index, changes: changes)
    end
  end
end
