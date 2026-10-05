defmodule Ingestor.Pipeline.Load do
  @moduledoc """
  Inserts company rows into ClickHouse in batches.

  ClickHouse is built for few large inserts: each insert creates a new data part on disk, so
  millions of single-row inserts would overload it with background merges.
  """

  alias Ingestor.ClickhouseRepo
  alias Ingestor.Companies.Company

  @default_batch_size 10_000

  @spec insert(Enumerable.t(map()), pos_integer()) :: non_neg_integer()
  def insert(companies, batch_size \\ @default_batch_size) do
    companies
    |> Stream.chunk_every(batch_size)
    |> Enum.reduce(0, fn batch, inserted ->
      {count, _} = ClickhouseRepo.insert_all(Company, batch)
      inserted + count
    end)
  end
end
