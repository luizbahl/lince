defmodule Ingestor.ChangesTest do
  use Ingestor.ClickhouseCase, async: false

  alias Ingestor.Changes

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

  defp establishment(reference_month, cnpj_order, overrides \\ %{}) do
    Map.merge(
      %{
        reference_month: reference_month,
        cnpj_root: "00000000",
        cnpj_order: cnpj_order,
        cnpj_check_digits: "91",
        registration_status_code: "02",
        registration_status_date: ~D[2005-11-03],
        main_cnae_code: "6422100",
        secondary_cnae_codes: ["6499999", "6619399"],
        special_status_date: nil
      },
      overrides
    )
  end

  defp stored_changes do
    Change
    |> ClickhouseRepo.all()
    |> Enum.map(
      &Map.take(&1, [:cnpj_root, :change_type, :field, :previous_value, :current_value])
    )
    |> Enum.sort_by(&{&1.cnpj_root, &1.field})
  end

  describe "replace_month/3 for companies" do
    test "stores one row per changed field, with both values as strings" do
      ClickhouseRepo.insert_all(Company, [
        company(@previous, "00000001", %{legal_name: "OLD LTDA"}),
        company(@current, "00000001", %{
          legal_name: "NEW LTDA",
          share_capital: Decimal.new("150.5")
        })
      ])

      assert Changes.replace_month(:companies, @current, @previous) == 2

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

    test "tags the change with the dataset and leaves the establishment key empty" do
      ClickhouseRepo.insert_all(Company, [
        company(@previous, "00000001", %{legal_name: "OLD LTDA"}),
        company(@current, "00000001", %{legal_name: "NEW LTDA"})
      ])

      Changes.replace_month(:companies, @current, @previous)

      assert [
               %Change{
                 dataset: "companies",
                 reference_month: @current,
                 cnpj_order: "",
                 cnpj_check_digits: ""
               }
             ] = ClickhouseRepo.all(Change)
    end

    test "detects created and removed companies and ignores unchanged ones" do
      ClickhouseRepo.insert_all(Company, [
        company(@previous, "00000001"),
        company(@current, "00000001"),
        company(@previous, "00000002"),
        company(@current, "00000003")
      ])

      assert Changes.replace_month(:companies, @current, @previous) == 2

      assert [
               %{cnpj_root: "00000002", change_type: "removed", field: ""},
               %{cnpj_root: "00000003", change_type: "created", field: ""}
             ] = stored_changes()
    end

    test "replaces only the changes of the same dataset and month" do
      ClickhouseRepo.insert_all(Change, [
        %{dataset: "companies", reference_month: @current, cnpj_root: "99999999"},
        %{dataset: "companies", reference_month: @previous, cnpj_root: "88888888"},
        %{dataset: "establishments", reference_month: @current, cnpj_root: "77777777"}
      ])

      ClickhouseRepo.insert_all(Company, [
        company(@previous, "00000001"),
        company(@current, "00000001")
      ])

      assert Changes.replace_month(:companies, @current, @previous) == 0

      assert [%{cnpj_root: "77777777"}, %{cnpj_root: "88888888"}] = stored_changes()
    end
  end

  describe "replace_month/3 for establishments" do
    test "compares each full CNPJ and stores its order and check digits" do
      ClickhouseRepo.insert_all(Establishment, [
        establishment(@previous, "0001"),
        establishment(@current, "0001", %{
          registration_status_code: "08",
          registration_status_date: ~D[2026-09-15]
        }),
        establishment(@previous, "0002"),
        establishment(@current, "0002")
      ])

      assert Changes.replace_month(:establishments, @current, @previous) == 2

      assert [status_date, status] =
               Change |> ClickhouseRepo.all() |> Enum.sort_by(& &1.field, :desc)

      assert %Change{
               dataset: "establishments",
               cnpj_order: "0001",
               cnpj_check_digits: "91",
               field: "registration_status_date",
               previous_value: "2005-11-03",
               current_value: "2026-09-15"
             } = status_date

      assert %{field: "registration_status_code", previous_value: "02", current_value: "08"} =
               status
    end

    test "a date that appears is a change and reordered CNAEs are not" do
      ClickhouseRepo.insert_all(Establishment, [
        establishment(@previous, "0001", %{secondary_cnae_codes: ["6499999", "6619399"]}),
        establishment(@current, "0001", %{
          secondary_cnae_codes: ["6619399", "6499999"],
          special_status_date: ~D[2026-09-10]
        })
      ])

      assert Changes.replace_month(:establishments, @current, @previous) == 1

      assert [%{field: "special_status_date", previous_value: "", current_value: "2026-09-10"}] =
               stored_changes()
    end

    test "a new branch is created with its full CNPJ" do
      ClickhouseRepo.insert_all(Establishment, [
        establishment(@previous, "0001"),
        establishment(@current, "0001"),
        establishment(@current, "0002")
      ])

      assert Changes.replace_month(:establishments, @current, @previous) == 1

      assert [%Change{change_type: "created", cnpj_order: "0002", cnpj_check_digits: "91"}] =
               ClickhouseRepo.all(Change)
    end
  end
end
