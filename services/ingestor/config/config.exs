import Config

config :ingestor, ecto_repos: [Ingestor.ClickhouseRepo]

import_config "#{config_env()}.exs"
