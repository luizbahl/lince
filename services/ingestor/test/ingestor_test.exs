defmodule IngestorTest do
  # End-to-end through the facade: zip -> extract -> parse -> ClickHouse.
  use Ingestor.ClickhouseCase, async: false

  import Ingestor.ReceitaFixtures

  alias Ingestor.Pipeline.DetectChanges
  alias Ingestor.Pipeline.ImportMonth

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

  defp import_establishments_month!(tmp_dir, reference_month, lines) do
    data_dir = new_dir!(tmp_dir, "establishments-#{reference_month}")
    estabelecimentos_zip!(data_dir, lines)

    {:ok, _} =
      Ingestor.import_establishments(%{data_dir: data_dir, reference_month: reference_month})
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

  describe "import_establishments/1" do
    test "imports every establishment of the month with its ClickHouse types",
         %{tmp_dir: tmp_dir} do
      estabelecimentos_zip!(tmp_dir, [
        establishment_line(cnpj_order: "0001", trade_name: "AÇÚCAR & CIA"),
        establishment_line(cnpj_order: "0002", branch_type_code: "2", secondary_cnae_codes: "")
      ])

      assert {:ok, %ImportMonth.Output{inserted: 2}} =
               Ingestor.import_establishments(%{
                 data_dir: tmp_dir,
                 reference_month: ~D[2026-09-01]
               })

      assert [headquarters, branch] =
               Establishment |> ClickhouseRepo.all() |> Enum.sort_by(& &1.cnpj_order)

      assert headquarters.trade_name == "AÇÚCAR & CIA"
      assert headquarters.activity_start_date == ~D[1966-08-01]
      assert headquarters.secondary_cnae_codes == ["6499999", "6619399"]
      assert branch.branch_type_code == "2"
      assert branch.secondary_cnae_codes == []
    end

    test "reads only Estabelecimentos files from a directory shared with other datasets",
         %{tmp_dir: tmp_dir} do
      empresas_zip!(tmp_dir, [company_line("00000000", "BANCO DO BRASIL SA")])
      estabelecimentos_zip!(tmp_dir, [establishment_line()])

      assert {:ok, %ImportMonth.Output{inserted: 1}} =
               Ingestor.import_establishments(%{
                 data_dir: tmp_dir,
                 reference_month: ~D[2026-09-01]
               })

      assert ClickhouseRepo.all(Company) == []
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

      assert {:ok, %DetectChanges.Output{changes: 3}} =
               Ingestor.detect_company_changes(%{reference_month: ~D[2026-09-01]})

      changes =
        Change
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

      assert ClickhouseRepo.all(Change) == [], "nothing is stored when a step fails"
    end

    test "returns the changeset when the input is invalid" do
      assert {:error, :invalid_input, changeset} =
               Ingestor.detect_company_changes(%{reference_month: ~D[2026-09-15]})

      assert {"must be the first day of the month", _} = changeset.errors[:reference_month]
    end
  end

  describe "detect_establishment_changes/1" do
    test "stores a closed headquarters and a removed branch", %{tmp_dir: tmp_dir} do
      import_establishments_month!(tmp_dir, ~D[2026-08-01], [
        establishment_line(cnpj_order: "0001"),
        establishment_line(cnpj_order: "0002", branch_type_code: "2")
      ])

      import_establishments_month!(tmp_dir, ~D[2026-09-01], [
        establishment_line(
          cnpj_order: "0001",
          registration_status_code: "08",
          registration_status_date: "20260915"
        )
      ])

      assert {:ok, %DetectChanges.Output{changes: 3}} =
               Ingestor.detect_establishment_changes(%{reference_month: ~D[2026-09-01]})

      changes =
        Change
        |> ClickhouseRepo.all()
        |> Map.new(&{{&1.cnpj_order, &1.field}, &1})

      assert %{previous_value: "02", current_value: "08"} =
               changes[{"0001", "registration_status_code"}]

      assert %{current_value: "2026-09-15"} = changes[{"0001", "registration_status_date"}]
      assert %{change_type: "removed"} = changes[{"0002", ""}]
    end

    test "checks the establishments months, not the companies ones", %{tmp_dir: tmp_dir} do
      import_month!(tmp_dir, ~D[2026-08-01], [company_line("00000000", "EMPRESA")])
      import_month!(tmp_dir, ~D[2026-09-01], [company_line("00000000", "EMPRESA")])
      import_establishments_month!(tmp_dir, ~D[2026-09-01], [establishment_line()])

      assert {:error, :month_not_imported, ~D[2026-08-01]} =
               Ingestor.detect_establishment_changes(%{reference_month: ~D[2026-09-01]})
    end
  end
end
