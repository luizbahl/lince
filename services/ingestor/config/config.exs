import Config

config :ingestor, ecto_repos: [Ingestor.ClickhouseRepo]

config :ingestor, IngestorWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [json: IngestorWeb.ErrorJSON], layout: false]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
