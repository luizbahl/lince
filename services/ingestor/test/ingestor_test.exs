defmodule IngestorTest do
  # End-to-end through the facade: zip -> extract -> parse -> ClickHouse.
  use Ingestor.ClickhouseCase, async: false

  import Ingestor.ReceitaFixtures

  alias Ingestor.Pipeline.ImportCompanies.Output

  @moduletag :tmp_dir

  describe "import_companies/1" do
    test "imports every company of the zip into ClickHouse", %{tmp_dir: tmp_dir} do
      zip_path =
        empresas_zip!(tmp_dir, [
          company_line("00000000", "BANCO DO BRASIL SA", "120000000000,00"),
          company_line("00000002", "AÇÚCAR LTDA")
        ])

      assert {:ok, %Output{inserted: 2}} =
               Ingestor.import_companies(%{zip_path: zip_path, reference_month: ~D[2026-09-01]})

      assert [banco, acucar] = ClickhouseRepo.all(Company) |> Enum.sort_by(& &1.cnpj_root)
      assert banco.legal_name == "BANCO DO BRASIL SA"
      assert Decimal.equal?(banco.share_capital, Decimal.new("120000000000.00"))
      assert acucar.legal_name == "AÇÚCAR LTDA", "ISO-8859-1 name must be stored as UTF-8"
    end

    test "returns the changeset when the input is invalid", %{tmp_dir: tmp_dir} do
      assert {:error, :invalid_input, changeset} =
               Ingestor.import_companies(%{
                 zip_path: Path.join(tmp_dir, "missing.zip"),
                 reference_month: ~D[2026-09-15]
               })

      assert {"file not found", _} = changeset.errors[:zip_path]
      assert {"must be the first day of the month", _} = changeset.errors[:reference_month]
      assert ClickhouseRepo.all(Company) == [], "nothing is loaded when a step fails"
    end
  end
end
