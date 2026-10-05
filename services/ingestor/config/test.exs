import Config

config :ingestor, Ingestor.ClickhouseRepo,
  hostname: System.get_env("CLICKHOUSE_HOST", "localhost"),
  port: 8123,
  database: "lince_test",
  username: "lince",
  password: "lince"
