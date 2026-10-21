import Config

config :ingestor, Ingestor.ClickhouseRepo,
  hostname: System.get_env("CLICKHOUSE_HOST", "localhost"),
  port: 8123,
  database: "lince",
  username: "lince",
  password: "lince"

config :ingestor, IngestorWeb.Endpoint, http: [ip: {0, 0, 0, 0}, port: 4002]
