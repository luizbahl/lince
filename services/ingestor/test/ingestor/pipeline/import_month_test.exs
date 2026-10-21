defmodule Ingestor.Pipeline.ImportMonthTest do
  use Ingestor.ClickhouseCase, async: false

  import Ingestor.ImportHelpers
  import Ingestor.ReceitaFixtures

  alias Ingestor.Pipeline.ImportMonth

  @moduletag :tmp_dir

  @month ~D[2026-09-01]

  defp run_import(dataset, data_dir, reference_month \\ @month) do
    ImportMonth.call(%ImportMonth.Input{
      dataset: dataset,
      data_dir: data_dir,
      reference_month: reference_month
    })
  end

  defp companies_by_cnpj_root do
    Company |> ClickhouseRepo.all() |> Map.new(&{&1.cnpj_root, &1})
  end

  describe "companies" do
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

      assert {:ok, %ImportMonth.Output{inserted: 3}} = run_import(:companies, tmp_dir)

      assert %{"00000000" => banco, "00000002" => acucar, "00000003" => _} =
               companies_by_cnpj_root()

      assert banco.legal_name == "BANCO DO BRASIL SA"
      assert Decimal.equal?(banco.share_capital, Decimal.new("120000000000.00"))
      assert acucar.legal_name == "AÇÚCAR LTDA", "ISO-8859-1 name must be stored as UTF-8"

      assert banco.imported_at == acucar.imported_at, "one timestamp for the whole import"
      assert DateTime.diff(DateTime.utc_now(), banco.imported_at) < 60
    end

    test "re-importing a month replaces it and keeps the other months", %{tmp_dir: tmp_dir} do
      import_month!(:companies, tmp_dir, ~D[2026-08-01], [company_line("00000009", "AUGUST")])

      first_dir = new_dir!(tmp_dir, "first")
      second_dir = new_dir!(tmp_dir, "second")

      empresas_zip!(first_dir, [
        company_line("00000001", "OLD NAME LTDA"),
        company_line("00000002", "GONE LTDA")
      ])

      empresas_zip!(second_dir, [company_line("00000001", "NEW NAME LTDA")])

      assert {:ok, _} = run_import(:companies, first_dir)
      assert {:ok, _} = run_import(:companies, second_dir)

      assert %{"00000001" => company, "00000009" => _} = companies = companies_by_cnpj_root()
      assert map_size(companies) == 2, "a company missing from the new files is removed"
      assert company.legal_name == "NEW NAME LTDA"
    end

    test "a failed re-import keeps the month as it was", %{tmp_dir: tmp_dir} do
      import_month!(:companies, tmp_dir, @month, [company_line("00000001", "EMPRESA")])

      broken_dir = new_dir!(tmp_dir, "broken")

      empresas_zip!(broken_dir, [
        company_line("00000002", "EMPRESA"),
        ~s("00000003";"MISSING FIELDS";"2062"\n)
      ])

      assert {:error, :load_failed, %FunctionClauseError{}} = run_import(:companies, broken_dir)

      assert Map.keys(companies_by_cnpj_root()) == ["00000001"]
    end
  end

  describe "establishments" do
    test "imports every establishment of the month with its ClickHouse types",
         %{tmp_dir: tmp_dir} do
      estabelecimentos_zip!(tmp_dir, [
        establishment_line(cnpj_order: "0001", trade_name: "AÇÚCAR & CIA"),
        establishment_line(cnpj_order: "0002", branch_type_code: "2", secondary_cnae_codes: "")
      ])

      assert {:ok, %ImportMonth.Output{inserted: 2}} = run_import(:establishments, tmp_dir)

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

      assert {:ok, %ImportMonth.Output{inserted: 1}} = run_import(:establishments, tmp_dir)

      assert ClickhouseRepo.all(Company) == []
    end
  end

  describe "errors" do
    test "returns :no_files when the directory has no zip of the dataset", %{tmp_dir: tmp_dir} do
      assert {:error, :no_files, ^tmp_dir} = run_import(:companies, tmp_dir)
    end

    test "returns the changeset when the input is invalid", %{tmp_dir: tmp_dir} do
      assert {:error, :invalid_input, changeset} =
               run_import(:companies, Path.join(tmp_dir, "missing"), ~D[2026-09-15])

      assert {"directory not found", _} = changeset.errors[:data_dir]
      assert {"must be the first day of the month", _} = changeset.errors[:reference_month]
      assert ClickhouseRepo.all(Company) == [], "nothing is loaded when a step fails"
    end

    test "returns the changeset for an unknown dataset", %{tmp_dir: tmp_dir} do
      assert {:error, :invalid_input, changeset} = run_import(:partners, tmp_dir)

      assert {"is invalid", _} = changeset.errors[:dataset]
    end
  end
end
