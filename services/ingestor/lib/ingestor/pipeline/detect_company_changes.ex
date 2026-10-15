defmodule Ingestor.Pipeline.DetectCompanyChanges do
  @moduledoc """
  Detects what changed in the companies of a reference month compared with the month before:

      validate_input_parameters -> put_previous_month -> ensure_months_imported -> detect -> output

  Both months must already be imported, otherwise every company would show up as created (or
  removed). Running it again for the same month replaces the previous result.
  """

  use Ingestor.Pipeline

  alias Ingestor.{Companies, CompanyChanges}

  defmodule Input do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field(:reference_month, :date)
    end

    @doc false
    def changeset(%Input{} = input \\ %Input{}, attrs) do
      input
      |> cast(attrs, [:reference_month])
      |> validate_required([:reference_month])
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
    |> put_previous_month()
    |> ensure_months_imported()
    |> detect()
    |> output()
  end

  defp put_previous_month({:error, _, _} = error), do: error

  defp put_previous_month({:ok, params}) do
    {:ok, Map.put(params, :previous_month, Date.shift(params.reference_month, month: -1))}
  end

  defp ensure_months_imported({:error, _, _} = error), do: error

  defp ensure_months_imported({:ok, params}) do
    case Enum.reject([params.previous_month, params.reference_month], &Companies.imported?/1) do
      [] -> {:ok, params}
      [missing_month | _] -> {:error, :month_not_imported, missing_month}
    end
  end

  defp detect({:error, _, _} = error), do: error

  defp detect({:ok, params}) do
    changes = CompanyChanges.replace_month(params.reference_month, params.previous_month)
    {:ok, Map.put(params, :changes, changes)}
  rescue
    exception -> {:error, :detect_failed, exception}
  end

  defp output({:error, _, _} = error), do: error

  defp output({:ok, %{changes: changes}}) do
    {:ok, %Output{changes: changes}}
  end
end
