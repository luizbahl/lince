defmodule Ingestor.Pipeline.ImportCompanies do
  @moduledoc """
  Imports one Receita Federal `Empresas*.zip` file into ClickHouse:

      validate_input_parameters -> put_imported_at -> extract -> load -> output

  Re-importing a file is safe: every row carries the same `imported_at`, the version column of
  the `companies` ReplacingMergeTree, so the newer import replaces the older one.
  """

  use Ingestor.Pipeline

  alias Ingestor.{Companies, Receita}

  defmodule Input do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field(:zip_path, :string)
      field(:reference_month, :date)
    end

    @doc false
    def changeset(%Input{} = input \\ %Input{}, attrs) do
      input
      |> cast(attrs, [:zip_path, :reference_month])
      |> validate_required([:zip_path, :reference_month])
      |> validate_change(:zip_path, fn :zip_path, path ->
        if File.regular?(path), do: [], else: [zip_path: "file not found"]
      end)
      |> validate_change(:reference_month, fn :reference_month, date ->
        if date.day == 1, do: [], else: [reference_month: "must be the first day of the month"]
      end)
    end
  end

  defmodule Output do
    @moduledoc false
    defstruct [:inserted]
  end

  def call(attrs) do
    tmp_dir = Path.join(System.tmp_dir!(), "ingestor-#{System.unique_integer([:positive])}")

    try do
      attrs
      |> validate_input_parameters(Input)
      |> put_imported_at()
      |> extract(tmp_dir)
      |> load()
      |> output()
    after
      File.rm_rf!(tmp_dir)
    end
  end

  defp put_imported_at({:error, _, _} = error), do: error

  defp put_imported_at({:ok, params}) do
    {:ok, Map.put(params, :imported_at, DateTime.utc_now())}
  end

  defp extract({:error, _, _} = error, _tmp_dir), do: error

  defp extract({:ok, params}, tmp_dir) do
    File.mkdir_p!(tmp_dir)

    case Receita.Zip.extract(params.zip_path, tmp_dir) do
      {:ok, csv_paths} -> {:ok, Map.put(params, :csv_paths, csv_paths)}
      {:error, reason} -> {:error, :extract_failed, reason}
    end
  end

  defp load({:error, _, _} = error), do: error

  defp load({:ok, params}) do
    inserted =
      params.csv_paths
      |> Enum.map(fn csv_path ->
        csv_path
        |> Receita.Companies.stream(params.reference_month)
        |> Stream.map(&Map.put(&1, :imported_at, params.imported_at))
        |> Companies.insert_in_batches()
      end)
      |> Enum.sum()

    {:ok, Map.put(params, :inserted, inserted)}
  rescue
    exception -> {:error, :load_failed, exception}
  end

  defp output({:error, _, _} = error), do: error

  defp output({:ok, %{inserted: inserted}}) do
    {:ok, %Output{inserted: inserted}}
  end
end
