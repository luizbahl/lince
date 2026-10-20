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
      schema: Establishment,
      key_columns: [:cnpj_root, :cnpj_order, :cnpj_check_digits],
      compared_fields: [
        trade_name: "toString(trade_name)",
        registration_status_code: "toString(registration_status_code)",
        registration_status_date: "ifNull(toString(registration_status_date), '')",
        registration_status_reason_code: "toString(registration_status_reason_code)",
        main_cnae_code: "toString(main_cnae_code)",
        secondary_cnae_codes: "arrayStringConcat(arraySort(secondary_cnae_codes), ',')",
        street_type: "toString(street_type)",
        street: "toString(street)",
        street_number: "toString(street_number)",
        address_complement: "toString(address_complement)",
        neighborhood: "toString(neighborhood)",
        postal_code: "toString(postal_code)",
        state_code: "toString(state_code)",
        municipality_code: "toString(municipality_code)",
        special_status: "toString(special_status)",
        special_status_date: "ifNull(toString(special_status_date), '')"
      ]
    }
  }

  @spec names() :: [atom()]
  def names, do: @datasets |> Map.keys() |> Enum.sort()

  @spec with_change_detection() :: [atom()]
  def with_change_detection do
    @datasets
    |> Enum.filter(fn {_name, config} -> Map.has_key?(config, :compared_fields) end)
    |> Enum.map(fn {name, _config} -> name end)
    |> Enum.sort()
  end

  @spec fetch!(atom()) :: map()
  def fetch!(name), do: Map.fetch!(@datasets, name)
end
