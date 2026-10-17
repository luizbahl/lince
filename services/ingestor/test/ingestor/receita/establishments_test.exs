defmodule Ingestor.Receita.EstablishmentsTest do
  use ExUnit.Case, async: true

  import Ingestor.ReceitaFixtures

  alias Ingestor.Receita.{CSV, Establishments}

  @month ~D[2026-09-01]

  defp parse(line) do
    [fields] = CSV.parse_string(line, skip_headers: false)
    Establishments.to_establishment(fields, @month)
  end

  describe "to_establishment/2" do
    test "maps the 30 Receita fields to the establishments columns" do
      assert %{
               reference_month: @month,
               cnpj_root: "00000000",
               cnpj_order: "0001",
               cnpj_check_digits: "91",
               branch_type_code: "1",
               registration_status_code: "02",
               registration_status_date: ~D[2005-11-03],
               activity_start_date: ~D[1966-08-01],
               main_cnae_code: "6422100",
               secondary_cnae_codes: ["6499999", "6619399"],
               street: "BANCARIO SUL",
               postal_code: "70074900",
               state_code: "DF",
               municipality_code: "9701",
               phone_1: "34939002",
               special_status_date: nil
             } = parse(establishment_line())
    end

    test "converts text from ISO-8859-1 to UTF-8" do
      line = establishment_line(trade_name: "AÇÚCAR & CIA", neighborhood: "SÃO JOÃO")

      assert %{trade_name: "AÇÚCAR & CIA", neighborhood: "SÃO JOÃO"} = parse(line)
    end

    test "turns missing dates into nil and an empty CNAE list into []" do
      line =
        establishment_line(
          registration_status_date: "0",
          activity_start_date: "",
          secondary_cnae_codes: ""
        )

      assert %{registration_status_date: nil, activity_start_date: nil, secondary_cnae_codes: []} =
               parse(line)
    end

    test "raises on a line with the wrong number of fields" do
      assert_raise FunctionClauseError, fn ->
        Establishments.to_establishment(["00000000", "0001", "91"], @month)
      end
    end
  end

  describe "stream/2" do
    @tag :tmp_dir
    test "streams every line of the file, including the first one", %{tmp_dir: tmp_dir} do
      csv_path = Path.join(tmp_dir, "estabelecimentos.csv")

      File.write!(csv_path, [
        establishment_line(cnpj_order: "0001"),
        establishment_line(cnpj_order: "0002", branch_type_code: "2")
      ])

      assert [%{cnpj_order: "0001"}, %{cnpj_order: "0002", branch_type_code: "2"}] =
               csv_path |> Establishments.stream(@month) |> Enum.to_list()
    end
  end
end
