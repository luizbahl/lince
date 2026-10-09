defmodule Ingestor.CompanyChanges.CompanyChange do
  @moduledoc """
  One difference found for a company (CNPJ root) between a reference month and the month before.

  Maps the `company_changes` ClickHouse table, one row per changed field:

    * `created` – the CNPJ root is in the month but not in the previous one (`field` is empty);
    * `removed` – the CNPJ root was in the previous month but is gone (`field` is empty);
    * `updated` – `field` went from `previous_value` to `current_value`.

  Values are stored as strings so fields of any type (e.g. `share_capital`) fit the same column.
  The table is partitioned by `reference_month`, so re-detecting a month drops its partition and
  inserts the result again.
  """

  use Ecto.Schema

  @primary_key false
  schema "company_changes" do
    field :reference_month, :date
    field :cnpj_root, Ch, type: "FixedString(8)"
    field :change_type, Ch, type: "LowCardinality(String)"
    field :field, Ch, type: "LowCardinality(String)"
    field :previous_value, Ch, type: "String"
    field :current_value, Ch, type: "String"
    field :detected_at, Ch, type: "DateTime64(3, 'UTC')"
  end
end
