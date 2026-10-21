defmodule Ingestor.ImportHelpers do
  @moduledoc """
  Prepares imported months for tests that need data already in ClickHouse (change detection,
  listing). Imports go straight through `Ingestor.Pipeline.ImportMonth`, not the facade.
  """

  import Ingestor.ReceitaFixtures

  alias Ingestor.Pipeline.ImportMonth

  @doc """
  Creates `name` inside `tmp_dir` and returns its path.
  """
  def new_dir!(tmp_dir, name) do
    tmp_dir |> Path.join(name) |> tap(&File.mkdir_p!/1)
  end

  @doc """
  Writes `lines` as the dataset's zip in a new directory and imports it as `reference_month`.
  """
  def import_month!(dataset, tmp_dir, reference_month, lines) do
    data_dir = new_dir!(tmp_dir, "#{dataset}-#{reference_month}")
    write_zip!(dataset, data_dir, lines)

    {:ok, _} =
      ImportMonth.call(%ImportMonth.Input{
        dataset: dataset,
        data_dir: data_dir,
        reference_month: reference_month
      })
  end

  defp write_zip!(:companies, dir, lines), do: empresas_zip!(dir, lines)
  defp write_zip!(:establishments, dir, lines), do: estabelecimentos_zip!(dir, lines)
end
