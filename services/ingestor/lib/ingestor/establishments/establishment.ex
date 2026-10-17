defmodule Ingestor.Establishments.Establishment do
  @moduledoc """
  One establishment (full 14-digit CNPJ: headquarters or branch) as published by Receita Federal
  in a given reference month.

  Maps the `establishments` ClickHouse table. The full CNPJ is split as in the source file:
  `cnpj_root` (8 digits, shared with `companies`), `cnpj_order` (4) and `cnpj_check_digits` (2).

  Dates are `Date32` because `Date` starts in 1970 and some establishments are older; they are
  `nil` when Receita Federal publishes no date. Each month is written as a whole partition (see
  `Ingestor.MonthlyTables`).
  """

  use Ecto.Schema

  @primary_key false
  schema "establishments" do
    field :reference_month, :date
    field :cnpj_root, Ch, type: "FixedString(8)"
    field :cnpj_order, Ch, type: "FixedString(4)"
    field :cnpj_check_digits, Ch, type: "FixedString(2)"
    field :branch_type_code, Ch, type: "LowCardinality(String)"
    field :trade_name, Ch, type: "String"
    field :registration_status_code, Ch, type: "LowCardinality(String)"
    field :registration_status_date, Ch, type: "Nullable(Date32)"
    field :registration_status_reason_code, Ch, type: "LowCardinality(String)"
    field :foreign_city_name, Ch, type: "String"
    field :country_code, Ch, type: "LowCardinality(String)"
    field :activity_start_date, Ch, type: "Nullable(Date32)"
    field :main_cnae_code, Ch, type: "LowCardinality(String)"
    field :secondary_cnae_codes, Ch, type: "Array(String)"
    field :street_type, Ch, type: "LowCardinality(String)"
    field :street, Ch, type: "String"
    field :street_number, Ch, type: "String"
    field :address_complement, Ch, type: "String"
    field :neighborhood, Ch, type: "String"
    field :postal_code, Ch, type: "String"
    field :state_code, Ch, type: "LowCardinality(String)"
    field :municipality_code, Ch, type: "LowCardinality(String)"
    field :phone_1_area_code, Ch, type: "String"
    field :phone_1, Ch, type: "String"
    field :phone_2_area_code, Ch, type: "String"
    field :phone_2, Ch, type: "String"
    field :fax_area_code, Ch, type: "String"
    field :fax, Ch, type: "String"
    field :email, Ch, type: "String"
    field :special_status, Ch, type: "String"
    field :special_status_date, Ch, type: "Nullable(Date32)"
    field :imported_at, Ch, type: "DateTime64(3, 'UTC')"
  end
end
