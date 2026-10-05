defmodule Ingestor.ClickhouseRepo do
  @moduledoc false
  use Ecto.Repo, otp_app: :ingestor, adapter: Ecto.Adapters.ClickHouse
end
