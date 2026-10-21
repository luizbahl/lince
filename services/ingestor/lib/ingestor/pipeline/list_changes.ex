defmodule Ingestor.Pipeline.ListChanges do
  @moduledoc """
  Lists the changes detected for a CNPJ, newest month first:

      validate_input_parameters -> split_cnpj -> fetch_changes -> output

  The CNPJ may be the 8-character root (the company and all its establishments) or the full
  14 characters (one establishment plus its company-level changes), with or without punctuation.
  Since July 2026 CNPJs may contain letters in the first 12 positions; the 2 check digits are
  always numeric.
  """

  use Ingestor.Pipeline

  alias Ingestor.Changes

  defmodule Input do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @cnpj_format ~r/\A[0-9A-Z]{8}([0-9A-Z]{4}[0-9]{2})?\z/

    embedded_schema do
      field(:cnpj, :string)
      field(:since, :date)
    end

    @doc false
    def changeset(%Input{} = input \\ %Input{}, attrs) do
      input
      |> cast(attrs, [:cnpj, :since])
      |> validate_required([:cnpj])
      |> update_change(:cnpj, &normalize_cnpj/1)
      |> validate_format(:cnpj, @cnpj_format,
        message: "must be a CNPJ root (8 characters) or a full CNPJ (14 characters)"
      )
    end

    defp normalize_cnpj(cnpj) do
      cnpj
      |> String.replace(~r/[.\/\-\s]/, "")
      |> String.upcase()
    end
  end

  defmodule Output do
    @moduledoc false
    defstruct [:changes]
  end

  def call(attrs) do
    attrs
    |> validate_input_parameters(Input)
    |> split_cnpj()
    |> fetch_changes()
    |> output()
  end

  defp split_cnpj({:error, _, _} = error), do: error

  defp split_cnpj({:ok, %{cnpj: <<root::binary-8>>} = params}) do
    {:ok, Map.merge(params, %{cnpj_root: root, cnpj_order: nil, cnpj_check_digits: nil})}
  end

  defp split_cnpj(
         {:ok, %{cnpj: <<root::binary-8, order::binary-4, check_digits::binary-2>>} = params}
       ) do
    {:ok,
     Map.merge(params, %{cnpj_root: root, cnpj_order: order, cnpj_check_digits: check_digits})}
  end

  defp fetch_changes({:error, _, _} = error), do: error

  defp fetch_changes({:ok, params}) do
    {:ok, Map.put(params, :changes, Changes.list(params))}
  rescue
    exception -> {:error, :fetch_failed, exception}
  end

  defp output({:error, _, _} = error), do: error

  defp output({:ok, %{changes: changes}}) do
    {:ok, %Output{changes: changes}}
  end
end
