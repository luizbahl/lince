defmodule Ingestor.ClickhouseCase do
  @moduledoc """
  Test case for tests that touch ClickHouse.

  ClickHouse has no transactions, so there is no Ecto sandbox: each test starts by truncating the
  tables it uses. For the same reason these tests cannot run concurrently (`async: false`).
  """

  use ExUnit.CaseTemplate

  alias Ingestor.ClickhouseRepo

  @tables ~w(companies companies_staging company_changes establishments establishments_staging)

  using do
    quote do
      alias Ingestor.ClickhouseRepo
      alias Ingestor.Schemas.Company
      alias Ingestor.Schemas.CompanyChange
      alias Ingestor.Schemas.Establishment
    end
  end

  setup do
    Enum.each(@tables, &ClickhouseRepo.query!("TRUNCATE TABLE #{&1}"))
    :ok
  end
end
