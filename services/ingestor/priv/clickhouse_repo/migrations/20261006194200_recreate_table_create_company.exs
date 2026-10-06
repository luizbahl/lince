defmodule Ingestor.ClickhouseRepo.Migrations.RecreateTableCreateCompany do
  use Ecto.Migration

  def change do
    create table(:companies,
             primary_key: false,
             engine: "ReplacingMergeTree(imported_at)",
             options: "PARTITION BY reference_month ORDER BY (cnpj_root, reference_month)"
           ) do
      add :reference_month, :date
      add :cnpj_root, :"FixedString(8)"
      add :legal_name, :string
      add :legal_nature_code, :"LowCardinality(String)"
      add :responsible_qualification_code, :"LowCardinality(String)"
      add :share_capital, :"Decimal(18, 2)"
      add :size_code, :"LowCardinality(String)"
      add :federative_entity, :string
      add :imported_at, :"DateTime64(3, 'UTC')"
    end
  end
end
