defmodule Ingestor.Receita.CompaniesTest do
  use ExUnit.Case, async: true

  import Ingestor.ReceitaFixtures

  alias Ingestor.Receita.Companies

  @month ~D[2026-09-01]

  describe "to_company/2" do
    test "maps the 7 Receita fields to the companies columns" do
      fields = ["00000000", "BANCO DO BRASIL SA", "2038", "10", "120000000000,00", "05", ""]

      assert %{
               reference_month: @month,
               cnpj_root: "00000000",
               legal_name: "BANCO DO BRASIL SA",
               legal_nature_code: "2038",
               responsible_qualification_code: "10",
               size_code: "05",
               federative_entity: ""
             } = company = Companies.to_company(fields, @month)

      assert Decimal.equal?(company.share_capital, Decimal.new("120000000000.00"))
    end

    test "converts text from ISO-8859-1 to UTF-8" do
      latin1_name = <<"A", 0xC7, 0xDA, "CAR LTDA">>
      fields = ["00000002", latin1_name, "2062", "49", "0,00", "01", ""]

      assert %{legal_name: "AÇÚCAR LTDA"} = Companies.to_company(fields, @month)
    end

    test "reads the comma as the decimal separator" do
      fields = ["00000003", "EMPRESA", "2062", "49", "1500,75", "01", ""]

      assert Decimal.equal?(
               Companies.to_company(fields, @month).share_capital,
               Decimal.new("1500.75")
             )
    end
  end

  describe "stream/2" do
    # @tag :tmp_dir gives the test its own empty directory in `context.tmp_dir`.
    @tag :tmp_dir
    test "streams every line of the file, including the first one", %{tmp_dir: tmp_dir} do
      csv_path = Path.join(tmp_dir, "empresas.csv")

      File.write!(csv_path, [
        company_line("00000000", "PRIMEIRA"),
        company_line("00000001", "SEGUNDA")
      ])

      assert [%{cnpj_root: "00000000"}, %{cnpj_root: "00000001"}] =
               csv_path |> Companies.stream(@month) |> Enum.to_list()
    end
  end
end
