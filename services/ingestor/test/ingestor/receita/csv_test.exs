defmodule Ingestor.Receita.CSVTest do
  use ExUnit.Case, async: true

  alias Ingestor.Receita.CSV

  # A real line from Empresas1.zip (2026-09).
  @line ~s("00000000";"BANCO DO BRASIL SA";"2038";"10";"120000000000,00";"05";""\n)

  describe "parse_string/2" do
    test "splits a record into its 7 fields without the quotes" do
      assert CSV.parse_string(@line, skip_headers: false) == [
               ["00000000", "BANCO DO BRASIL SA", "2038", "10", "120000000000,00", "05", ""]
             ]
    end

    test "keeps the first line, since Receita files have no header" do
      assert CSV.parse_string(@line) == [],
             "default skip_headers: true drops the first record"

      assert [_record] = CSV.parse_string(@line, skip_headers: false)
    end

    test "does not split on a separator inside quotes" do
      line = ~s("00000001";"PADARIA PAO; CAFE LTDA";"2062";"49";"0,00";"01";""\n)

      assert [[_, "PADARIA PAO; CAFE LTDA" | _]] = CSV.parse_string(line, skip_headers: false)
    end

    test "leaves ISO-8859-1 bytes untouched" do
      # "AÇÚCAR" in ISO-8859-1: Ç = 0xC7, Ú = 0xDA (not valid UTF-8 on its own).
      latin1_name = <<"A", 0xC7, 0xDA, "CAR LTDA">>
      line = ~s("00000002";") <> latin1_name <> ~s(";"2062";"49";"0,00";"01";""\n)

      assert [[_, ^latin1_name | _]] = CSV.parse_string(line, skip_headers: false)
    end
  end

  describe "parse_stream/2" do
    test "parses a stream of lines lazily, one record per line" do
      lines = [
        ~s("00000000";"EMPRESA A";"2062";"49";"0,00";"01";""\n),
        ~s("00000001";"EMPRESA B";"2062";"49";"0,00";"01";""\n)
      ]

      records =
        lines
        |> CSV.parse_stream(skip_headers: false)
        |> Enum.map(fn [cnpj_root, legal_name | _] -> {cnpj_root, legal_name} end)

      assert records == [{"00000000", "EMPRESA A"}, {"00000001", "EMPRESA B"}]
    end
  end
end
