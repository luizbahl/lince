defmodule IngestorWeb.Endpoint do
  @moduledoc """
  Entry point of every HTTP request. Only the plugs a JSON API needs: no sessions, cookies or
  static files.
  """

  use Phoenix.Endpoint, otp_app: :ingestor

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["application/json"],
    json_decoder: Phoenix.json_library()

  plug IngestorWeb.Router
end
