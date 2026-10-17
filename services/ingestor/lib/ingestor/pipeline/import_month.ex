defmodule Ingestor.Pipeline.ImportMonth do
  @moduledoc """
  Imports every Receita Federal zip file of one dataset (e.g. all `Empresas*.zip`) from a month
  directory into ClickHouse:

      validate_input_parameters -> put_dataset -> put_imported_at -> list_zip_paths
        -> clear_staging -> load -> publish -> output

  The whole month is loaded into the dataset's staging table and only then swapped into the
  final table (see `Ingestor.MonthlyTables`), so re-importing a month replaces it completely and a
  failed import leaves the previous data untouched.

  Each dataset is described in `@datasets` by its file prefix, the `Ingestor.Receita` module that
  turns an extracted CSV into a stream of rows, and the Ecto schema of its table.
  """

  use Ingestor.Pipeline

  alias Ingestor.MonthlyTables
  alias Ingestor.Receita
  alias Ingestor.Schemas.Company
  alias Ingestor.Schemas.Establishment

  @datasets %{
    companies: %{file_prefix: "Empresas", parser: Receita.Companies, schema: Company},
    establishments: %{
      file_prefix: "Estabelecimentos",
      parser: Receita.Establishments,
      schema: Establishment
    }
  }

  defmodule Input do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field(:dataset, Ecto.Enum, values: [:companies, :establishments])
      field(:data_dir, :string)
      field(:reference_month, :date)
    end

    @doc false
    def changeset(%Input{} = input \\ %Input{}, attrs) do
      input
      |> cast(attrs, [:dataset, :data_dir, :reference_month])
      |> validate_required([:dataset, :data_dir, :reference_month])
      |> validate_change(:data_dir, fn :data_dir, path ->
        if File.dir?(path), do: [], else: [data_dir: "directory not found"]
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
      |> put_dataset()
      |> put_imported_at()
      |> list_zip_paths()
      |> clear_staging()
      |> load(tmp_dir)
      |> publish()
      |> output()
    after
      File.rm_rf!(tmp_dir)
    end
  end

  defp put_dataset({:error, _, _} = error), do: error

  defp put_dataset({:ok, params}) do
    {:ok, Map.merge(params, Map.fetch!(@datasets, params.dataset))}
  end

  defp put_imported_at({:error, _, _} = error), do: error

  defp put_imported_at({:ok, params}) do
    {:ok, Map.put(params, :imported_at, DateTime.utc_now())}
  end

  defp list_zip_paths({:error, _, _} = error), do: error

  defp list_zip_paths({:ok, params}) do
    pattern = Path.join(params.data_dir, "#{params.file_prefix}*.zip")

    case pattern |> Path.wildcard() |> Enum.sort() do
      [] -> {:error, :no_files, params.data_dir}
      zip_paths -> {:ok, Map.put(params, :zip_paths, zip_paths)}
    end
  end

  defp clear_staging({:error, _, _} = error), do: error

  defp clear_staging({:ok, params}) do
    case MonthlyTables.clear_staging(params.schema, params.reference_month) do
      :ok -> {:ok, params}
      {:error, exception} -> {:error, :load_failed, exception}
    end
  end

  defp load({:error, _, _} = error, _tmp_dir), do: error

  defp load({:ok, params}, tmp_dir) do
    params.zip_paths
    |> Enum.reduce_while({:ok, 0}, &load_zip(&1, &2, params, tmp_dir))
    |> case do
      {:ok, inserted} -> {:ok, Map.put(params, :inserted, inserted)}
      {:error, _, _} = error -> error
    end
  rescue
    exception -> {:error, :load_failed, exception}
  end

  defp load_zip(zip_path, {:ok, inserted_so_far}, params, tmp_dir) do
    extract_dir = Path.join(tmp_dir, Path.basename(zip_path, ".zip"))
    File.mkdir_p!(extract_dir)

    case Receita.Zip.extract(zip_path, extract_dir) do
      {:ok, csv_paths} ->
        inserted = Enum.sum_by(csv_paths, &stage_csv(&1, params))
        File.rm_rf!(extract_dir)
        {:cont, {:ok, inserted_so_far + inserted}}

      {:error, reason} ->
        {:halt, {:error, :extract_failed, {zip_path, reason}}}
    end
  end

  defp stage_csv(csv_path, params) do
    rows =
      csv_path
      |> params.parser.stream(params.reference_month)
      |> Stream.map(&Map.put(&1, :imported_at, params.imported_at))

    MonthlyTables.stage_in_batches(params.schema, rows)
  end

  defp publish({:error, _, _} = error), do: error

  defp publish({:ok, params}) do
    case MonthlyTables.publish_staging(params.schema, params.reference_month) do
      :ok -> {:ok, params}
      {:error, exception} -> {:error, :publish_failed, exception}
    end
  end

  defp output({:error, _, _} = error), do: error

  defp output({:ok, %{inserted: inserted}}) do
    {:ok, %Output{inserted: inserted}}
  end
end
