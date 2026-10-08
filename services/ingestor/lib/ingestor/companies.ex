defmodule Ingestor.Companies do
  @moduledoc """
  Persistence helpers for the `companies` table.

  ClickHouse is built for few large inserts: each insert creates a new data part on disk, so
  millions of single-row inserts would overload it with background merges.
  """

  import Ecto.Query

  alias Ingestor.ClickhouseRepo
  alias Ingestor.Companies.Company

  @default_batch_size 10_000

  @spec imported?(Date.t()) :: boolean()
  def imported?(%Date{} = reference_month) do
    Company
    |> where(reference_month: ^reference_month)
    |> ClickhouseRepo.exists?()
  end

  @spec insert_in_batches(Enumerable.t(map()), pos_integer()) :: non_neg_integer()
  def insert_in_batches(companies, batch_size \\ @default_batch_size) do
    companies
    |> Stream.chunk_every(batch_size)
    |> Enum.reduce(0, fn batch, inserted ->
      {count, _} = ClickhouseRepo.insert_all(Company, batch)
      inserted + count
    end)
  end
end
