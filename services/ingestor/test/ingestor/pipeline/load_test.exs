defmodule Ingestor.Pipeline.LoadTest do
  use Ingestor.ClickhouseCase, async: false

  alias Ingestor.Pipeline.Load

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

  test "inserts all rows, split in batches, and returns the count" do
    companies = Enum.map(["00000001", "00000002", "00000003"], &company/1)

    # batch_size 2 forces two inserts: one with 2 rows and one with 1.
    assert Load.insert(companies, 2) == 3

    assert ClickhouseRepo.all(Company) |> Enum.map(& &1.cnpj_root) |> Enum.sort() ==
             ["00000001", "00000002", "00000003"]
  end

  test "stores the values with their ClickHouse types" do
    Load.insert([company("00000001")])

    assert [stored] = ClickhouseRepo.all(Company)
    assert stored.reference_month == ~D[2026-09-01]
    assert Decimal.equal?(stored.share_capital, Decimal.new("1000.50"))
  end

  test "accepts an empty stream" do
    assert Load.insert([]) == 0
  end
end
