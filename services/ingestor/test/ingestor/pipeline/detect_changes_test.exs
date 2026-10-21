defmodule Ingestor.Pipeline.DetectChangesTest do
  use Ingestor.ClickhouseCase, async: false

  import Ingestor.ImportHelpers
  import Ingestor.ReceitaFixtures

  alias Ingestor.Pipeline.DetectChanges

  @moduletag :tmp_dir

  @previous ~D[2026-08-01]
  @current ~D[2026-09-01]

  defp detect(dataset, reference_month \\ @current) do
    DetectChanges.call(%DetectChanges.Input{dataset: dataset, reference_month: reference_month})
  end

  describe "companies" do
    test "stores what changed since the previous month", %{tmp_dir: tmp_dir} do
      import_month!(:companies, tmp_dir, @previous, [
        company_line("00000001", "OLD NAME LTDA"),
        company_line("00000002", "CLOSED LTDA")
      ])

      import_month!(:companies, tmp_dir, @current, [
        company_line("00000001", "NEW NAME LTDA"),
        company_line("00000003", "OPENED LTDA")
      ])

      assert {:ok, %DetectChanges.Output{changes: 3}} = detect(:companies)

      changes = Change |> ClickhouseRepo.all() |> Map.new(&{&1.cnpj_root, &1})

      assert %{field: "legal_name", previous_value: "OLD NAME LTDA"} = changes["00000001"]
      assert changes["00000001"].current_value == "NEW NAME LTDA"
      assert changes["00000002"].change_type == "removed"
      assert changes["00000003"].change_type == "created"
    end
  end

  describe "establishments" do
    test "stores a closed headquarters and a removed branch", %{tmp_dir: tmp_dir} do
      import_month!(:establishments, tmp_dir, @previous, [
        establishment_line(cnpj_order: "0001"),
        establishment_line(cnpj_order: "0002", branch_type_code: "2")
      ])

      import_month!(:establishments, tmp_dir, @current, [
        establishment_line(
          cnpj_order: "0001",
          registration_status_code: "08",
          registration_status_date: "20260915"
        )
      ])

      assert {:ok, %DetectChanges.Output{changes: 3}} = detect(:establishments)

      changes = Change |> ClickhouseRepo.all() |> Map.new(&{{&1.cnpj_order, &1.field}, &1})

      assert %{previous_value: "02", current_value: "08"} =
               changes[{"0001", "registration_status_code"}]

      assert %{current_value: "2026-09-15"} = changes[{"0001", "registration_status_date"}]
      assert %{change_type: "removed"} = changes[{"0002", ""}]
    end

    test "checks the establishments months, not the companies ones", %{tmp_dir: tmp_dir} do
      import_month!(:companies, tmp_dir, @previous, [company_line("00000000", "EMPRESA")])
      import_month!(:companies, tmp_dir, @current, [company_line("00000000", "EMPRESA")])
      import_month!(:establishments, tmp_dir, @current, [establishment_line()])

      assert {:error, :month_not_imported, @previous} = detect(:establishments)
    end
  end

  describe "errors" do
    test "returns :month_not_imported when the previous month is missing", %{tmp_dir: tmp_dir} do
      import_month!(:companies, tmp_dir, @current, [company_line("00000001", "EMPRESA")])

      assert {:error, :month_not_imported, @previous} = detect(:companies)
      assert ClickhouseRepo.all(Change) == [], "nothing is stored when a step fails"
    end

    test "returns :month_not_imported when the current month is missing", %{tmp_dir: tmp_dir} do
      import_month!(:companies, tmp_dir, @previous, [company_line("00000001", "EMPRESA")])

      assert {:error, :month_not_imported, @current} = detect(:companies)
    end

    test "returns the changeset when the month is not the first day" do
      assert {:error, :invalid_input, changeset} = detect(:companies, ~D[2026-09-15])

      assert {"must be the first day of the month", _} = changeset.errors[:reference_month]
    end

    test "returns the changeset for an unknown dataset" do
      assert {:error, :invalid_input, changeset} = detect(:partners)

      assert {"is invalid", _} = changeset.errors[:dataset]
    end
  end
end
