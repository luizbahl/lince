defmodule Ingestor.ClickhouseCase do
  @moduledoc """
  Test case for tests that touch ClickHouse.

  ClickHouse has no transactions, so there is no Ecto sandbox: each test starts by truncating the
  tables it uses. For the same reason these tests cannot run concurrently (`async: false`).
  """

  use ExUnit.CaseTemplate

  alias Ingestor.ClickhouseRepo

  using do
    quote do
      alias Ingestor.ClickhouseRepo
      alias Ingestor.Companies.Company
      alias Ingestor.CompanyChanges.CompanyChange
    end
  end

  setup do
    ClickhouseRepo.query!("TRUNCATE TABLE companies")
    ClickhouseRepo.query!("TRUNCATE TABLE company_changes")
    :ok
  end
end
