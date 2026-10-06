defmodule Ingestor.CompaniesTest do
  use Ingestor.ClickhouseCase, async: false

  alias Ingestor.Companies

  defp company(cnpj_root) do
    %{
      reference_month: ~D[2026-09-01],
      cnpj_root: cnpj_root,
      legal_name: "EMPRESA #{cnpj_root}",
      legal_nature_code: "2062",
      responsible_qualification_code: "49",
      share_capital: Decimal.new("1000.50"),
      size_code: "01",
      federative_entity: ""
    }
  end

  describe "insert_in_batches/2" do
    test "inserts all rows, split in batches, and returns the count" do
      companies = Enum.map(["00000001", "00000002", "00000003"], &company/1)

      # batch_size 2 forces two inserts: one with 2 rows and one with 1.
      assert Companies.insert_in_batches(companies, 2) == 3

      assert ClickhouseRepo.all(Company) |> Enum.map(& &1.cnpj_root) |> Enum.sort() ==
               ["00000001", "00000002", "00000003"]
    end

    test "stores the values with their ClickHouse types" do
      Companies.insert_in_batches([company("00000001")])

      assert [stored] = ClickhouseRepo.all(Company)
      assert stored.reference_month == ~D[2026-09-01]
      assert Decimal.equal?(stored.share_capital, Decimal.new("1000.50"))
    end

    test "accepts an empty stream" do
      assert Companies.insert_in_batches([]) == 0
    end
  end
end
