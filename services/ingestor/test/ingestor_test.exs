defmodule IngestorTest do
  # The facade's own responsibilities: picking the right dataset and forwarding optional keys.
  # Calls missing a required key are caught at compile time by the type checker, so they are not
  # tested here. Each pipeline's scenarios live in test/ingestor/pipeline/.
  use Ingestor.ClickhouseCase, async: false

  import Ingestor.ImportHelpers
  import Ingestor.ReceitaFixtures

  alias Ingestor.Pipeline.DetectChanges
  alias Ingestor.Pipeline.ImportMonth
  alias Ingestor.Pipeline.ListChanges

  @moduletag :tmp_dir

  @previous ~D[2026-08-01]
  @current ~D[2026-09-01]

  describe "import_companies/1" do
    test "imports the Empresas files into companies", %{tmp_dir: tmp_dir} do
      empresas_zip!(tmp_dir, [company_line("00000000", "EMPRESA")])

      assert {:ok, %ImportMonth.Output{inserted: 1}} =
               Ingestor.import_companies(%{data_dir: tmp_dir, reference_month: @current})

      assert [%Company{}] = ClickhouseRepo.all(Company)
    end
  end

  describe "import_establishments/1" do
    test "imports the Estabelecimentos files into establishments", %{tmp_dir: tmp_dir} do
      estabelecimentos_zip!(tmp_dir, [establishment_line()])

      assert {:ok, %ImportMonth.Output{inserted: 1}} =
               Ingestor.import_establishments(%{data_dir: tmp_dir, reference_month: @current})

      assert [%Establishment{}] = ClickhouseRepo.all(Establishment)
    end
  end

  describe "detect_company_changes/1" do
    test "detects changes of the companies dataset", %{tmp_dir: tmp_dir} do
      import_month!(:companies, tmp_dir, @previous, [company_line("00000001", "OLD LTDA")])
      import_month!(:companies, tmp_dir, @current, [company_line("00000001", "NEW LTDA")])

      assert {:ok, %DetectChanges.Output{changes: 1}} =
               Ingestor.detect_company_changes(%{reference_month: @current})

      assert [%Change{dataset: "companies"}] = ClickhouseRepo.all(Change)
    end
  end

  describe "detect_establishment_changes/1" do
    test "detects changes of the establishments dataset", %{tmp_dir: tmp_dir} do
      import_month!(:establishments, tmp_dir, @previous, [establishment_line()])

      import_month!(:establishments, tmp_dir, @current, [
        establishment_line(registration_status_code: "08")
      ])

      assert {:ok, %DetectChanges.Output{changes: 1}} =
               Ingestor.detect_establishment_changes(%{reference_month: @current})

      assert [%Change{dataset: "establishments"}] = ClickhouseRepo.all(Change)
    end
  end

  describe "list_changes/1" do
    setup do
      ClickhouseRepo.insert_all(Change, [
        %{dataset: "companies", reference_month: @previous, cnpj_root: "00000000"},
        %{dataset: "companies", reference_month: @current, cnpj_root: "00000000"}
      ])

      :ok
    end

    test "since is optional" do
      assert {:ok, %ListChanges.Output{changes: [_, _]}} =
               Ingestor.list_changes(%{cnpj: "00000000"})
    end

    test "forwards since to the pipeline" do
      assert {:ok, %ListChanges.Output{changes: [%Change{reference_month: @current}]}} =
               Ingestor.list_changes(%{cnpj: "00000000", since: @current})
    end
  end
end
