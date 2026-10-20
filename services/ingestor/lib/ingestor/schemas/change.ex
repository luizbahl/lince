defmodule Ingestor.Schemas.Change do
  @moduledoc """
  One difference found for a row of a dataset between a reference month and the month before.

  Maps the `changes` ClickHouse table, one row per changed field:

    * `created` – the row is in the month but not in the previous one (`field` is empty);
    * `removed` – the row was in the previous month but is gone (`field` is empty);
    * `updated` – `field` went from `previous_value` to `current_value`.

  The row is identified by `cnpj_root`, `cnpj_order` and `cnpj_check_digits`; the last two are
  empty for datasets keyed by the CNPJ root only (`companies`). Values are stored as strings so
  fields of any type fit the same column.

  The table is partitioned by `(reference_month, dataset)`, so re-detecting a month of one dataset
  drops only that partition and inserts the result again.
  """

  use Ecto.Schema

  @primary_key false
  schema "changes" do
    field :dataset, Ch, type: "LowCardinality(String)"
    field :reference_month, :date
    field :cnpj_root, Ch, type: "FixedString(8)"
    field :cnpj_order, Ch, type: "String"
    field :cnpj_check_digits, Ch, type: "String"
    field :change_type, Ch, type: "LowCardinality(String)"
    field :field, Ch, type: "LowCardinality(String)"
    field :previous_value, Ch, type: "String"
    field :current_value, Ch, type: "String"
    field :detected_at, Ch, type: "DateTime64(3, 'UTC')"
  end
end
