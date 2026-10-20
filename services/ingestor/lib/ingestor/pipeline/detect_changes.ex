defmodule Ingestor.Pipeline.DetectChanges do
  @moduledoc """
  Detects what changed in a dataset for a reference month compared with the month before:

      validate_input_parameters -> put_dataset -> put_previous_month -> ensure_months_imported
        -> detect -> output

  Both months must already be imported, otherwise every row would show up as created (or
  removed). Running it again for the same dataset and month replaces the previous result.
  """

  use Ingestor.Pipeline

  alias Ingestor.Changes
  alias Ingestor.Datasets
  alias Ingestor.MonthlyTables

  defmodule Input do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field(:dataset, Ecto.Enum, values: Ingestor.Datasets.with_change_detection())
      field(:reference_month, :date)
    end

    @doc false
    def changeset(%Input{} = input \\ %Input{}, attrs) do
      input
      |> cast(attrs, [:dataset, :reference_month])
      |> validate_required([:dataset, :reference_month])
      |> validate_change(:reference_month, fn :reference_month, date ->
        if date.day == 1, do: [], else: [reference_month: "must be the first day of the month"]
      end)
    end
  end

  defmodule Output do
    @moduledoc false
    defstruct [:changes]
  end

  def call(attrs) do
    attrs
    |> validate_input_parameters(Input)
    |> put_dataset()
    |> put_previous_month()
    |> ensure_months_imported()
    |> detect()
    |> output()
  end

  defp put_dataset({:error, _, _} = error), do: error

  defp put_dataset({:ok, params}) do
    {:ok, Map.put(params, :schema, Datasets.fetch!(params.dataset).schema)}
  end

  defp put_previous_month({:error, _, _} = error), do: error

  defp put_previous_month({:ok, params}) do
    {:ok, Map.put(params, :previous_month, Date.shift(params.reference_month, month: -1))}
  end

  defp ensure_months_imported({:error, _, _} = error), do: error

  defp ensure_months_imported({:ok, params}) do
    months = [params.previous_month, params.reference_month]

    case Enum.reject(months, &MonthlyTables.imported?(params.schema, &1)) do
      [] -> {:ok, params}
      [missing_month | _] -> {:error, :month_not_imported, missing_month}
    end
  end

  defp detect({:error, _, _} = error), do: error

  defp detect({:ok, params}) do
    changes =
      Changes.replace_month(params.dataset, params.reference_month, params.previous_month)

    {:ok, Map.put(params, :changes, changes)}
  rescue
    exception -> {:error, :detect_failed, exception}
  end

  defp output({:error, _, _} = error), do: error

  defp output({:ok, %{changes: changes}}) do
    {:ok, %Output{changes: changes}}
  end
end
