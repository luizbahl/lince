defmodule Ingestor.Datasets do
  @moduledoc """
  The Receita Federal datasets the ingestor handles, and how each one is imported and compared.

  Every dataset has:

    * `file_prefix` – name of its zip files in a month directory (`Empresas0.zip`...);
    * `parser` – the `Ingestor.Receita` module that turns an extracted CSV into rows;
    * `schema` – the Ecto schema of its ClickHouse table.

  Datasets with change detection also have:

    * `key_columns` – the columns that identify one row within a month;
    * `compared_fields` – the columns compared from one month to the next, each with the SQL
      expression that turns it into a string (see `Ingestor.Changes`).
  """

  alias Ingestor.Receita
  alias Ingestor.Schemas.Company
  alias Ingestor.Schemas.Establishment

  @datasets %{
    companies: %{
      file_prefix: "Empresas",
      parser: Receita.Companies,
      schema: Company,
      key_columns: [:cnpj_root],
      compared_fields: [
        legal_name: "toString(legal_name)",
        legal_nature_code: "toString(legal_nature_code)",
        responsible_qualification_code: "toString(responsible_qualification_code)",
        share_capital: "toDecimalString(share_capital, 2)",
        size_code: "toString(size_code)",
        federative_entity: "toString(federative_entity)"
      ]
    },
    establishments: %{
      file_prefix: "Estabelecimentos",
      parser: Receita.Establishments,
      schema: Establishment
    }
  }

  @spec names() :: [atom()]
  def names, do: @datasets |> Map.keys() |> Enum.sort()

  @spec with_change_detection() :: [atom()]
  def with_change_detection do
    for {name, %{compared_fields: _}} <- @datasets, do: name
  end

  @spec fetch!(atom()) :: map()
  def fetch!(name), do: Map.fetch!(@datasets, name)
end
