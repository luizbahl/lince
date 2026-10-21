import Config

config :ingestor, Ingestor.ClickhouseRepo,
  hostname: System.get_env("CLICKHOUSE_HOST", "localhost"),
  port: 8123,
  database: "lince_test",
  username: "lince",
  password: "lince"

config :ingestor, IngestorWeb.Endpoint, http: [port: 4102], server: false

# Hide Ecto's per-query debug logs during tests.
config :logger, level: :warning
