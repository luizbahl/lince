defmodule Ingestor.Companies.Company do
  @moduledoc """
  One company (CNPJ root) as published by Receita Federal in a given reference month.

  Maps the `companies` ClickHouse table. Field types use `Ch` with the exact ClickHouse type,
  because inserts are encoded in ClickHouse's binary format, where e.g. `FixedString(8)` and
  `String` are written differently.

  The table is a `ReplacingMergeTree` versioned by `imported_at`: re-importing a month inserts
  new rows and ClickHouse keeps only the latest per `(cnpj_root, reference_month)`. Until
  background merges run, both versions exist, so reads must use `FINAL`
  (`Repo.all(Company, settings: [final: 1])`).
  """

  use Ecto.Schema

  @primary_key false
  schema "companies" do
    field :reference_month, :date
    field :cnpj_root, Ch, type: "FixedString(8)"
    field :legal_name, Ch, type: "String"
    field :legal_nature_code, Ch, type: "LowCardinality(String)"
    field :responsible_qualification_code, Ch, type: "LowCardinality(String)"
    field :share_capital, Ch, type: "Decimal(18, 2)"
    field :size_code, Ch, type: "LowCardinality(String)"
    field :federative_entity, Ch, type: "String"
    field :imported_at, Ch, type: "DateTime64(3, 'UTC')"
  end
end
