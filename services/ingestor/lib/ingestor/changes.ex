defmodule Ingestor.Changes do
  @moduledoc """
  Detects what changed in a dataset's table from one reference month to the next and stores the
  result in `changes`.

  The comparison runs entirely inside ClickHouse, so none of the ~60M rows of each month is sent
  to Elixir. Both months are grouped by the dataset's key columns instead of joined: a
  `FULL OUTER JOIN` would hold a whole month in memory as a hash table, while `GROUP BY` can spill
  to disk.

  The SQL is built from the dataset's `key_columns` and `compared_fields` (see
  `Ingestor.Datasets`). Only values from that configuration are interpolated; the months and the
  dataset name are query parameters.
  """

  import Ecto.Query

  alias Ingestor.ClickhouseRepo
  alias Ingestor.Datasets
  alias Ingestor.Schemas.Change

  @doc """
  Compares `current_month` with `previous_month` for `dataset` and replaces the changes stored for
  that dataset and `current_month`. Returns how many changes were stored.
  """
  @spec replace_month(atom(), Date.t(), Date.t()) :: non_neg_integer()
  def replace_month(dataset, %Date{} = current_month, %Date{} = previous_month) do
    config = Datasets.fetch!(dataset)

    delete_month(dataset, current_month)

    ClickhouseRepo.query!(detect_sql(config), [
      current_month,
      previous_month,
      Atom.to_string(dataset)
    ])

    count_month(dataset, current_month)
  end

  defp detect_sql(config) do
    table = config.schema.__schema__(:source)
    keys = Enum.join(config.key_columns, ", ")
    field_names = Enum.map_join(config.compared_fields, ", ", fn {name, _} -> "'#{name}'" end)

    field_values =
      Enum.map_join(config.compared_fields, ", ", fn {_, expression} -> expression end)

    """
    INSERT INTO changes
      (dataset, reference_month, cnpj_root, cnpj_order, cnpj_check_digits,
       change_type, field, previous_value, current_value, detected_at)
    SELECT
      {$2:String}, {$0:Date}, cnpj_root,
      #{key_or_empty(config, :cnpj_order)}, #{key_or_empty(config, :cnpj_check_digits)},
      change.1, change.2, change.3, change.4, now64(3, 'UTC')
    FROM (
      SELECT
        #{keys},
        countIf(reference_month = {$1:Date}) > 0 AS in_previous,
        countIf(reference_month = {$0:Date}) > 0 AS in_current,
        anyIf(fields, reference_month = {$1:Date}) AS previous_fields,
        anyIf(fields, reference_month = {$0:Date}) AS current_fields
      FROM (
        SELECT #{keys}, reference_month, [#{field_values}] AS fields
        FROM #{table}
        WHERE reference_month IN ({$1:Date}, {$0:Date})
      )
      GROUP BY #{keys}
    )
    ARRAY JOIN multiIf(
      NOT in_previous, [('created', '', '', '')],
      NOT in_current, [('removed', '', '', '')],
      arrayMap(
        t -> ('updated', t.1, t.2, t.3),
        arrayFilter(t -> t.2 != t.3, arrayZip([#{field_names}], previous_fields, current_fields))
      )
    ) AS change
    """
  end

  defp key_or_empty(config, column) do
    if column in config.key_columns, do: "toString(#{column})", else: "''"
  end

  defp delete_month(dataset, month) do
    ClickhouseRepo.query!(
      "ALTER TABLE changes DROP PARTITION ('#{Date.to_iso8601(month)}', '#{dataset}')"
    )
  end

  defp count_month(dataset, month) do
    Change
    |> where(dataset: ^Atom.to_string(dataset), reference_month: ^month)
    |> ClickhouseRepo.aggregate(:count)
  end
end
