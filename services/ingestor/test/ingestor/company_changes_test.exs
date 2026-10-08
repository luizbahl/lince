defmodule Ingestor.CompanyChangesTest do
  use Ingestor.ClickhouseCase, async: false

  alias Ingestor.{Companies, CompanyChanges}

  @previous ~D[2026-08-01]
  @current ~D[2026-09-01]

  defp company(reference_month, cnpj_root, overrides \\ %{}) do
    Map.merge(
      %{
        reference_month: reference_month,
        cnpj_root: cnpj_root,
        legal_name: "EMPRESA #{cnpj_root}",
        legal_nature_code: "2062",
        responsible_qualification_code: "49",
        share_capital: Decimal.new("100.00"),
        size_code: "01",
        federative_entity: ""
      },
      overrides
    )
  end

  defp stored_changes do
    CompanyChange
    |> ClickhouseRepo.all()
    |> Enum.map(
      &Map.take(&1, [:cnpj_root, :change_type, :field, :previous_value, :current_value])
    )
    |> Enum.sort_by(&{&1.cnpj_root, &1.field})
  end

  describe "replace_month/2" do
    test "stores one row per changed field, with both values as strings" do
      Companies.insert_in_batches([
        company(@previous, "00000001", %{legal_name: "OLD LTDA"}),
        company(@current, "00000001", %{
          legal_name: "NEW LTDA",
          share_capital: Decimal.new("150.5")
        })
      ])

      assert CompanyChanges.replace_month(@current, @previous) == 2

      assert stored_changes() == [
               %{
                 cnpj_root: "00000001",
                 change_type: "updated",
                 field: "legal_name",
                 previous_value: "OLD LTDA",
                 current_value: "NEW LTDA"
               },
               %{
                 cnpj_root: "00000001",
                 change_type: "updated",
                 field: "share_capital",
                 previous_value: "100.00",
                 current_value: "150.50"
               }
             ]
    end

    test "detects created and removed companies and ignores unchanged ones" do
      Companies.insert_in_batches([
        company(@previous, "00000001"),
        company(@current, "00000001"),
        company(@previous, "00000002"),
        company(@current, "00000003")
      ])

      assert CompanyChanges.replace_month(@current, @previous) == 2

      assert [
               %{cnpj_root: "00000002", change_type: "removed", field: ""},
               %{cnpj_root: "00000003", change_type: "created", field: ""}
             ] = stored_changes()
    end

    test "replaces the changes of the month and keeps the other months" do
      ClickhouseRepo.insert_all(CompanyChange, [
        %{reference_month: @current, cnpj_root: "99999999", change_type: "created"},
        %{reference_month: @previous, cnpj_root: "88888888", change_type: "created"}
      ])

      Companies.insert_in_batches([company(@previous, "00000001"), company(@current, "00000001")])

      assert CompanyChanges.replace_month(@current, @previous) == 0
      assert [%{cnpj_root: "88888888"}] = stored_changes()
    end
  end
end
