defmodule Ingestor.Pipeline do
  @moduledoc """
  Shared behaviour for pipelines: `use Ingestor.Pipeline` in a pipeline module.

  A pipeline defines a nested `Input` (an `embedded_schema` with a `changeset/1`) and `Output`
  (a struct), and a `call/1` that pipes the result of `validate_input_parameters/2` through its
  steps. Every step returns `{:ok, params}` or `{:error, type, detail}`, and its first clause
  passes an error along, so the first failing step short-circuits the rest.
  """

  defmacro __using__(_opts) do
    quote do
      import Ingestor.Pipeline, only: [validate_input_parameters: 2]
    end
  end

  @spec validate_input_parameters(map(), module()) ::
          {:ok, map()} | {:error, :invalid_input, Ecto.Changeset.t()}
  # A struct is also a map, so this clause must come first. Ecto's cast/4 rejects structs as
  # params, hence the conversion.
  def validate_input_parameters(%_{} = input, input_module) do
    input |> Map.from_struct() |> validate_input_parameters(input_module)
  end

  def validate_input_parameters(attrs, input_module) do
    attrs
    |> input_module.changeset()
    |> Ecto.Changeset.apply_action(:validate)
    |> case do
      {:ok, input} -> {:ok, Map.from_struct(input)}
      {:error, changeset} -> {:error, :invalid_input, changeset}
    end
  end
end
