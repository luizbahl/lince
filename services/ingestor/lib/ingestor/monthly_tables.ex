defmodule Ingestor.MonthlyTables do
  @moduledoc """
  Persistence helpers for tables that hold one partition per reference month, such as
  `companies`. Every function takes the table's Ecto schema.

  A month is never written straight into the table. Its rows are first staged in
  `<table>_staging`, which has the same structure, and then swapped in with
  `REPLACE PARTITION`, which is atomic: readers see either the old month or the new one, never a
  half-loaded month, and rows missing from the new files disappear with the old partition.

  ClickHouse is built for few large inserts: each insert creates a new data part on disk, so
  millions of single-row inserts would overload it with background merges.
  """

  import Ecto.Query

  alias Ingestor.ClickhouseRepo

  @default_batch_size 10_000

  @spec imported?(module(), Date.t()) :: boolean()
  def imported?(schema, %Date{} = reference_month) do
    schema
    |> where(reference_month: ^reference_month)
    |> ClickhouseRepo.exists?()
  end

  @spec stage_in_batches(module(), Enumerable.t(map()), pos_integer()) :: non_neg_integer()
  def stage_in_batches(schema, rows, batch_size \\ @default_batch_size) do
    staging = {staging_table(schema), schema}

    rows
    |> Stream.chunk_every(batch_size)
    |> Enum.reduce(0, fn batch, inserted ->
      {count, _} = ClickhouseRepo.insert_all(staging, batch)
      inserted + count
    end)
  end

  @spec clear_staging(module(), Date.t()) :: :ok | {:error, Exception.t()}
  def clear_staging(schema, %Date{} = reference_month) do
    run("ALTER TABLE #{staging_table(schema)} DROP PARTITION #{partition(reference_month)}")
  end

  @spec publish_staging(module(), Date.t()) :: :ok | {:error, Exception.t()}
  def publish_staging(schema, %Date{} = reference_month) do
    with :ok <-
           run(
             "ALTER TABLE #{table(schema)} REPLACE PARTITION #{partition(reference_month)} " <>
               "FROM #{staging_table(schema)}"
           ) do
      clear_staging(schema, reference_month)
    end
  end

  @spec staging_table(module()) :: String.t()
  def staging_table(schema), do: table(schema) <> "_staging"

  defp table(schema), do: schema.__schema__(:source)

  defp partition(%Date{} = reference_month), do: "'#{Date.to_iso8601(reference_month)}'"

  defp run(sql) do
    case ClickhouseRepo.query(sql) do
      {:ok, _} -> :ok
      {:error, exception} -> {:error, exception}
    end
  end
end
