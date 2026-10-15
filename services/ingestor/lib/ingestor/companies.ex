defmodule Ingestor.Companies do
  @moduledoc """
  Persistence helpers for the `companies` table.

  A month is never written straight into `companies`. Its rows are first staged in
  `companies_staging`, which has the same structure, and then swapped in with
  `REPLACE PARTITION`, which is atomic: readers see either the old month or the new one, never a
  half-loaded month, and companies missing from the new files disappear with the old partition.

  ClickHouse is built for few large inserts: each insert creates a new data part on disk, so
  millions of single-row inserts would overload it with background merges.
  """

  import Ecto.Query

  alias Ingestor.ClickhouseRepo
  alias Ingestor.Companies.Company

  @staging {"companies_staging", Company}
  @default_batch_size 10_000

  @spec imported?(Date.t()) :: boolean()
  def imported?(%Date{} = reference_month) do
    Company
    |> where(reference_month: ^reference_month)
    |> ClickhouseRepo.exists?()
  end

  @spec stage_in_batches(Enumerable.t(map()), pos_integer()) :: non_neg_integer()
  def stage_in_batches(companies, batch_size \\ @default_batch_size) do
    companies
    |> Stream.chunk_every(batch_size)
    |> Enum.reduce(0, fn batch, inserted ->
      {count, _} = ClickhouseRepo.insert_all(@staging, batch)
      inserted + count
    end)
  end

  @spec clear_staging(Date.t()) :: :ok | {:error, Exception.t()}
  def clear_staging(%Date{} = reference_month) do
    run("ALTER TABLE companies_staging DROP PARTITION #{partition(reference_month)}")
  end

  @spec publish_staging(Date.t()) :: :ok | {:error, Exception.t()}
  def publish_staging(%Date{} = reference_month) do
    with :ok <-
           run(
             "ALTER TABLE companies REPLACE PARTITION #{partition(reference_month)} " <>
               "FROM companies_staging"
           ) do
      clear_staging(reference_month)
    end
  end

  defp partition(%Date{} = reference_month), do: "'#{Date.to_iso8601(reference_month)}'"

  defp run(sql) do
    case ClickhouseRepo.query(sql) do
      {:ok, _} -> :ok
      {:error, exception} -> {:error, exception}
    end
  end
end
