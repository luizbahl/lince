defmodule Ingestor.CompaniesTest do
  use Ingestor.ClickhouseCase, async: false

  alias Ingestor.Companies

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

  describe "imported?/1" do
    test "tells whether the month has any company" do
      ClickhouseRepo.insert_all(Company, [company("00000001")])

      assert Companies.imported?(~D[2026-09-01])
      refute Companies.imported?(~D[2026-08-01])
    end
  end

  describe "stage_in_batches/2" do
    test "inserts all rows into the staging table, split in batches, and returns the count" do
      companies = Enum.map(["00000001", "00000002", "00000003"], &company/1)

      assert Companies.stage_in_batches(companies, 2) == 3

      assert cnpj_roots(@staging) == ["00000001", "00000002", "00000003"]
      assert cnpj_roots(Company) == [], "nothing reaches companies before publish"
    end

    test "stores the values with their ClickHouse types" do
      Companies.stage_in_batches([company("00000001")])

      assert [stored] = ClickhouseRepo.all(@staging)
      assert stored.reference_month == ~D[2026-09-01]
      assert Decimal.equal?(stored.share_capital, Decimal.new("1000.50"))
    end

    test "accepts an empty stream" do
      assert Companies.stage_in_batches([]) == 0
    end
  end

  describe "publish_staging/1" do
    test "replaces the month in companies and empties its staging partition" do
      ClickhouseRepo.insert_all(Company, [
        company("00000001"),
        company("00000002"),
        company("00000009", ~D[2026-08-01])
      ])

      Companies.stage_in_batches([company("00000001"), company("00000003")])

      assert Companies.publish_staging(~D[2026-09-01]) == :ok

      assert cnpj_roots(Company) == ["00000001", "00000003", "00000009"]
      assert cnpj_roots(@staging) == []
    end
  end

  describe "clear_staging/1" do
    test "drops only the given month from the staging table" do
      Companies.stage_in_batches([company("00000001"), company("00000002", ~D[2026-08-01])])

      assert Companies.clear_staging(~D[2026-09-01]) == :ok

      assert cnpj_roots(@staging) == ["00000002"]
    end
  end
end
