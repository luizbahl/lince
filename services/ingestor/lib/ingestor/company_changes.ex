defmodule Ingestor.CompanyChanges do
  @moduledoc """
  Detects what changed in the `companies` table from one reference month to the next and stores
  the result in `company_changes`.

  The comparison runs entirely inside ClickHouse, so none of the ~60M rows of each month is sent
  to Elixir. Both months are grouped by `cnpj_root` instead of joined: a `FULL OUTER JOIN` would
  hold a whole month in memory as a hash table, while `GROUP BY` can spill to disk.
  """

  import Ecto.Query

  alias Ingestor.ClickhouseRepo
  alias Ingestor.CompanyChanges.CompanyChange

  @compared_fields [
    legal_name: "toString(legal_name)",
    legal_nature_code: "toString(legal_nature_code)",
    responsible_qualification_code: "toString(responsible_qualification_code)",
    share_capital: "toDecimalString(share_capital, 2)",
    size_code: "toString(size_code)",
    federative_entity: "toString(federative_entity)"
  ]

  @field_names Enum.map_join(@compared_fields, ", ", fn {name, _} -> "'#{name}'" end)
  @field_values Enum.map_join(@compared_fields, ", ", fn {_, expression} -> expression end)

  @detect_sql """
  INSERT INTO company_changes
    (reference_month, cnpj_root, change_type, field, previous_value, current_value, detected_at)
  SELECT {$0:Date}, cnpj_root, change.1, change.2, change.3, change.4, now64(3, 'UTC')
  FROM (
    SELECT
      cnpj_root,
      countIf(reference_month = {$1:Date}) > 0 AS in_previous,
      countIf(reference_month = {$0:Date}) > 0 AS in_current,
      anyIf(fields, reference_month = {$1:Date}) AS previous_fields,
      anyIf(fields, reference_month = {$0:Date}) AS current_fields
    FROM (
      SELECT cnpj_root, reference_month, [#{@field_values}] AS fields
      FROM companies FINAL
      WHERE reference_month IN ({$1:Date}, {$0:Date})
    )
    GROUP BY cnpj_root
  )
  ARRAY JOIN multiIf(
    NOT in_previous, [('created', '', '', '')],
    NOT in_current, [('removed', '', '', '')],
    arrayMap(
      t -> ('updated', t.1, t.2, t.3),
      arrayFilter(t -> t.2 != t.3, arrayZip([#{@field_names}], previous_fields, current_fields))
    )
  ) AS change
  """

  @doc """
  Compares `current_month` with `previous_month` and replaces the changes stored for
  `current_month`. Returns how many changes were stored.
  """
  @spec replace_month(Date.t(), Date.t()) :: non_neg_integer()
  def replace_month(%Date{} = current_month, %Date{} = previous_month) do
    delete_month(current_month)
    ClickhouseRepo.query!(@detect_sql, [current_month, previous_month])
    count_month(current_month)
  end

  defp delete_month(month) do
    ClickhouseRepo.query!(
      "ALTER TABLE company_changes DROP PARTITION '#{Date.to_iso8601(month)}'"
    )
  end

  defp count_month(month) do
    CompanyChange
    |> where(reference_month: ^month)
    |> ClickhouseRepo.aggregate(:count)
  end
end
