defmodule Ingestor.Receita.FieldsTest do
  use ExUnit.Case, async: true

  alias Ingestor.Receita.Fields

  describe "text/1" do
    test "converts ISO-8859-1 to UTF-8" do
      assert Fields.text(<<"A", 0xC7, 0xDA, "CAR">>) == "AÇÚCAR"
    end
  end

  describe "decimal/1" do
    test "reads the comma as the decimal separator" do
      assert Decimal.equal?(Fields.decimal("1500,75"), Decimal.new("1500.75"))
    end
  end

  describe "date/1" do
    test "parses YYYYMMDD" do
      assert Fields.date("19660801") == ~D[1966-08-01]
    end

    test "returns nil for missing dates" do
      assert Fields.date("") == nil
      assert Fields.date("0") == nil
      assert Fields.date("00000000") == nil
    end

    test "returns nil for invalid dates and years before 1900" do
      assert Fields.date("20230230") == nil
      assert Fields.date("18991231") == nil
      assert Fields.date("2023-01-01") == nil
    end
  end

  describe "list/1" do
    test "splits on commas" do
      assert Fields.list("4751201,4789099") == ["4751201", "4789099"]
    end

    test "returns an empty list for an empty field" do
      assert Fields.list("") == []
    end
  end
end
