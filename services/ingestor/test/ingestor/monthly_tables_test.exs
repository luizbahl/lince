defmodule Ingestor.MonthlyTablesTest do
  use Ingestor.ClickhouseCase, async: false

  alias Ingestor.MonthlyTables

  @staging {"companies_staging", Company}

  defp company(cnpj_root, reference_month \\ ~D[2026-09-01]) do
    %{
      reference_month: reference_month,
      cnpj_root: cnpj_root,
      legal_name: "EMPRESA #{cnpj_root}",
      legal_nature_code: "2062",
      responsible_qualification_code: "49",
      share_capital: Decimal.new("1000.50"),
      size_code: "01",
      federative_entity: ""
    }
  end

  defp cnpj_roots(source) do
    source |> ClickhouseRepo.all() |> Enum.map(& &1.cnpj_root) |> Enum.sort()
  end

  describe "imported?/2" do
    test "tells whether the month has any row" do
      ClickhouseRepo.insert_all(Company, [company("00000001")])

      assert MonthlyTables.imported?(Company, ~D[2026-09-01])
      refute MonthlyTables.imported?(Company, ~D[2026-08-01])
    end
  end

  describe "staging_table/1" do
    test "is the schema's table with a _staging suffix" do
      assert MonthlyTables.staging_table(Company) == "companies_staging"
    end
  end

  describe "stage_in_batches/3" do
    test "inserts all rows into the staging table, split in batches, and returns the count" do
      companies = Enum.map(["00000001", "00000002", "00000003"], &company/1)

      assert MonthlyTables.stage_in_batches(Company, companies, 2) == 3

      assert cnpj_roots(@staging) == ["00000001", "00000002", "00000003"]
      assert cnpj_roots(Company) == [], "nothing reaches the table before publish"
    end

    test "stores the values with their ClickHouse types" do
      MonthlyTables.stage_in_batches(Company, [company("00000001")])

      assert [stored] = ClickhouseRepo.all(@staging)
      assert stored.reference_month == ~D[2026-09-01]
      assert Decimal.equal?(stored.share_capital, Decimal.new("1000.50"))
    end

    test "accepts an empty stream" do
      assert MonthlyTables.stage_in_batches(Company, []) == 0
    end
  end

  describe "publish_staging/2" do
    test "replaces the month in the table and empties its staging partition" do
      ClickhouseRepo.insert_all(Company, [
        company("00000001"),
        company("00000002"),
        company("00000009", ~D[2026-08-01])
      ])

      MonthlyTables.stage_in_batches(Company, [company("00000001"), company("00000003")])

      assert MonthlyTables.publish_staging(Company, ~D[2026-09-01]) == :ok

      assert cnpj_roots(Company) == ["00000001", "00000003", "00000009"]
      assert cnpj_roots(@staging) == []
    end
  end

  describe "clear_staging/2" do
    test "drops only the given month from the staging table" do
      MonthlyTables.stage_in_batches(Company, [
        company("00000001"),
        company("00000002", ~D[2026-08-01])
      ])

      assert MonthlyTables.clear_staging(Company, ~D[2026-09-01]) == :ok

      assert cnpj_roots(@staging) == ["00000002"]
    end
  end
end
