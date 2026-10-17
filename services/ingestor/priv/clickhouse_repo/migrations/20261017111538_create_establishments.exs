defmodule Ingestor.ClickhouseRepo.Migrations.CreateEstablishments do
  use Ecto.Migration

  def change do
    create_establishments_table(:establishments)
    create_establishments_table(:establishments_staging)
  end

  defp create_establishments_table(name) do
    create table(name,
             primary_key: false,
             engine: "MergeTree",
             options:
               "PARTITION BY reference_month " <>
                 "ORDER BY (cnpj_root, cnpj_order, cnpj_check_digits, reference_month)"
           ) do
      add :reference_month, :date
      add :cnpj_root, :"FixedString(8)"
      add :cnpj_order, :"FixedString(4)"
      add :cnpj_check_digits, :"FixedString(2)"
      add :branch_type_code, :"LowCardinality(String)"
      add :trade_name, :string
      add :registration_status_code, :"LowCardinality(String)"
      add :registration_status_date, :"Nullable(Date32)"
      add :registration_status_reason_code, :"LowCardinality(String)"
      add :foreign_city_name, :string
      add :country_code, :"LowCardinality(String)"
      add :activity_start_date, :"Nullable(Date32)"
      add :main_cnae_code, :"LowCardinality(String)"
      add :secondary_cnae_codes, :"Array(String)"
      add :street_type, :"LowCardinality(String)"
      add :street, :string
      add :street_number, :string
      add :address_complement, :string
      add :neighborhood, :string
      add :postal_code, :string
      add :state_code, :"LowCardinality(String)"
      add :municipality_code, :"LowCardinality(String)"
      add :phone_1_area_code, :string
      add :phone_1, :string
      add :phone_2_area_code, :string
      add :phone_2, :string
      add :fax_area_code, :string
      add :fax, :string
      add :email, :string
      add :special_status, :string
      add :special_status_date, :"Nullable(Date32)"
      add :imported_at, :"DateTime64(3, 'UTC')"
    end
  end
end
