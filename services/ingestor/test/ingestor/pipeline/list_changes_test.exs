defmodule Ingestor.Pipeline.ListChangesTest do
  use Ingestor.ClickhouseCase, async: false

  alias Ingestor.Pipeline.ListChanges

  @month ~D[2026-09-01]

  defp list(cnpj, since \\ nil) do
    ListChanges.call(%ListChanges.Input{cnpj: cnpj, since: since})
  end

  setup do
    ClickhouseRepo.insert_all(Change, [
      %{dataset: "companies", reference_month: @month, cnpj_root: "00000000", field: "a"},
      %{
        dataset: "establishments",
        reference_month: @month,
        cnpj_root: "00000000",
        cnpj_order: "0001",
        cnpj_check_digits: "91",
        field: "b"
      },
      %{
        dataset: "establishments",
        reference_month: @month,
        cnpj_root: "00000000",
        cnpj_order: "0002",
        cnpj_check_digits: "72",
        field: "c"
      }
    ])

    :ok
  end

  defp fields({:ok, %ListChanges.Output{changes: changes}}), do: Enum.map(changes, & &1.field)

  describe "CNPJ formats" do
    test "a root lists the company and all its establishments" do
      assert list("00000000") |> fields() == ["a", "b", "c"]
    end

    test "a full CNPJ lists that establishment and the company-level changes" do
      assert list("00000000000191") |> fields() == ["a", "b"]
    end

    test "punctuation and spaces are ignored" do
      assert list(" 00.000.000/0001-91 ") |> fields() == ["a", "b"]
    end

    test "letters are accepted in the first 12 characters, in any case" do
      assert {:ok, %ListChanges.Output{changes: []}} = list("12.abc.345/01de-35")
    end

    test "since keeps only changes from that month on" do
      assert list("00000000", ~D[2026-10-01]) |> fields() == []
    end
  end

  describe "errors" do
    test "returns the changeset for a CNPJ with the wrong length" do
      assert {:error, :invalid_input, changeset} = list("123")

      assert {"must be a CNPJ root (8 characters) or a full CNPJ (14 characters)", _} =
               changeset.errors[:cnpj]
    end

    test "returns the changeset for letters in the check digits" do
      assert {:error, :invalid_input, _changeset} = list("12ABC34501DEAB")
    end

    test "returns the changeset when the CNPJ is missing" do
      assert {:error, :invalid_input, changeset} = list(nil)

      assert {"can't be blank", _} = changeset.errors[:cnpj]
    end
  end
end
