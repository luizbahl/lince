defmodule IngestorTest do
  # End-to-end through the facade: zip -> extract -> parse -> ClickHouse.
  use Ingestor.ClickhouseCase, async: false

  import Ingestor.ReceitaFixtures

  alias Ingestor.Pipeline.{DetectCompanyChanges, ImportMonth}

  @moduletag :tmp_dir

  defp new_dir!(tmp_dir, name) do
    tmp_dir |> Path.join(name) |> tap(&File.mkdir_p!/1)
  end

  defp import_month!(tmp_dir, reference_month, lines) do
    data_dir = new_dir!(tmp_dir, Date.to_iso8601(reference_month))
    empresas_zip!(data_dir, lines)

    {:ok, _} =
      Ingestor.import_companies(%{data_dir: data_dir, reference_month: reference_month})
  end

  defp companies_by_cnpj_root do
    Company |> ClickhouseRepo.all() |> Map.new(&{&1.cnpj_root, &1})
  end

  describe "import_companies/1" do
    test "imports every company of every zip of the month", %{tmp_dir: tmp_dir} do
      empresas_zip!(
        tmp_dir,
        [
          company_line("00000000", "BANCO DO BRASIL SA", "120000000000,00"),
          company_line("00000002", "AÇÚCAR LTDA")
        ],
        "Empresas0.zip"
      )

      empresas_zip!(tmp_dir, [company_line("00000003", "OUTRA LTDA")], "Empresas1.zip")

      assert {:ok, %ImportMonth.Output{inserted: 3}} =
               Ingestor.import_companies(%{data_dir: tmp_dir, reference_month: ~D[2026-09-01]})

      assert %{"00000000" => banco, "00000002" => acucar, "00000003" => _} =
               companies_by_cnpj_root()

      assert banco.legal_name == "BANCO DO BRASIL SA"
      assert Decimal.equal?(banco.share_capital, Decimal.new("120000000000.00"))
      assert acucar.legal_name == "AÇÚCAR LTDA", "ISO-8859-1 name must be stored as UTF-8"

      assert banco.imported_at == acucar.imported_at, "one timestamp for the whole import"
      assert DateTime.diff(DateTime.utc_now(), banco.imported_at) < 60
    end

    test "re-importing a month replaces it and keeps the other months", %{tmp_dir: tmp_dir} do
      import_month!(tmp_dir, ~D[2026-08-01], [company_line("00000009", "AUGUST LTDA")])

      first_dir = new_dir!(tmp_dir, "first")
      second_dir = new_dir!(tmp_dir, "second")

      empresas_zip!(first_dir, [
        company_line("00000001", "OLD NAME LTDA"),
        company_line("00000002", "GONE LTDA")
      ])

      empresas_zip!(second_dir, [company_line("00000001", "NEW NAME LTDA")])

      month = ~D[2026-09-01]
      assert {:ok, _} = Ingestor.import_companies(%{data_dir: first_dir, reference_month: month})
      assert {:ok, _} = Ingestor.import_companies(%{data_dir: second_dir, reference_month: month})

      assert %{"00000001" => company, "00000009" => _} = companies = companies_by_cnpj_root()
      assert map_size(companies) == 2, "a company missing from the new files is removed"
      assert company.legal_name == "NEW NAME LTDA"
    end

    test "a failed re-import keeps the month as it was", %{tmp_dir: tmp_dir} do
      import_month!(tmp_dir, ~D[2026-09-01], [company_line("00000001", "EMPRESA")])

      broken_dir = new_dir!(tmp_dir, "broken")

      empresas_zip!(broken_dir, [
        company_line("00000002", "EMPRESA"),
        ~s("00000003";"MISSING FIELDS";"2062"\n)
      ])

      assert {:error, :load_failed, %FunctionClauseError{}} =
               Ingestor.import_companies(%{data_dir: broken_dir, reference_month: ~D[2026-09-01]})

      assert Map.keys(companies_by_cnpj_root()) == ["00000001"]
    end

    test "returns :no_files when the directory has no Empresas zip", %{tmp_dir: tmp_dir} do
      assert {:error, :no_files, ^tmp_dir} =
               Ingestor.import_companies(%{data_dir: tmp_dir, reference_month: ~D[2026-09-01]})
    end

    test "returns the changeset when the input is invalid", %{tmp_dir: tmp_dir} do
      assert {:error, :invalid_input, changeset} =
               Ingestor.import_companies(%{
                 data_dir: Path.join(tmp_dir, "missing"),
                 reference_month: ~D[2026-09-15]
               })

      assert {"directory not found", _} = changeset.errors[:data_dir]
      assert {"must be the first day of the month", _} = changeset.errors[:reference_month]
      assert ClickhouseRepo.all(Company) == [], "nothing is loaded when a step fails"
    end
  end

  describe "detect_company_changes/1" do
    test "stores what changed since the previous month", %{tmp_dir: tmp_dir} do
      import_month!(tmp_dir, ~D[2026-08-01], [
        company_line("00000001", "OLD NAME LTDA"),
        company_line("00000002", "CLOSED LTDA")
      ])

      import_month!(tmp_dir, ~D[2026-09-01], [
        company_line("00000001", "NEW NAME LTDA"),
        company_line("00000003", "OPENED LTDA")
      ])

      assert {:ok, %DetectCompanyChanges.Output{changes: 3}} =
               Ingestor.detect_company_changes(%{reference_month: ~D[2026-09-01]})

      changes =
        CompanyChange
        |> ClickhouseRepo.all()
        |> Map.new(&{&1.cnpj_root, &1})

      assert %{field: "legal_name", previous_value: "OLD NAME LTDA"} = changes["00000001"]
      assert changes["00000001"].current_value == "NEW NAME LTDA"
      assert changes["00000002"].change_type == "removed"
      assert changes["00000003"].change_type == "created"
    end

    test "returns :month_not_imported when the previous month is missing", %{tmp_dir: tmp_dir} do
      import_month!(tmp_dir, ~D[2026-09-01], [company_line("00000001", "EMPRESA")])

      assert {:error, :month_not_imported, ~D[2026-08-01]} =
               Ingestor.detect_company_changes(%{reference_month: ~D[2026-09-01]})

      assert ClickhouseRepo.all(CompanyChange) == [], "nothing is stored when a step fails"
    end

    test "returns the changeset when the input is invalid" do
      assert {:error, :invalid_input, changeset} =
               Ingestor.detect_company_changes(%{reference_month: ~D[2026-09-15]})

      assert {"must be the first day of the month", _} = changeset.errors[:reference_month]
    end
  end
end
