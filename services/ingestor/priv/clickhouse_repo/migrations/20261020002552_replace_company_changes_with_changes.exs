defmodule Ingestor.ClickhouseRepo.Migrations.ReplaceCompanyChangesWithChanges do
  use Ecto.Migration

  def up do
    drop table(:company_changes)

    create table(:changes,
             primary_key: false,
             engine: "MergeTree",
             options:
               "PARTITION BY (reference_month, dataset) " <>
                 "ORDER BY (cnpj_root, cnpj_order, cnpj_check_digits, reference_month, dataset, field)"
           ) do
      add :dataset, :"LowCardinality(String)"
      add :reference_month, :date
      add :cnpj_root, :"FixedString(8)"
      add :cnpj_order, :string
      add :cnpj_check_digits, :string
      add :change_type, :"LowCardinality(String)"
      add :field, :"LowCardinality(String)"
      add :previous_value, :string
      add :current_value, :string
      add :detected_at, :"DateTime64(3, 'UTC')"
    end
  end

  def down do
    drop table(:changes)

    create table(:company_changes,
             primary_key: false,
             engine: "MergeTree",
             options: "PARTITION BY reference_month ORDER BY (cnpj_root, reference_month, field)"
           ) do
      add :reference_month, :date
      add :cnpj_root, :"FixedString(8)"
      add :change_type, :"LowCardinality(String)"
      add :field, :"LowCardinality(String)"
      add :previous_value, :string
      add :current_value, :string
      add :detected_at, :"DateTime64(3, 'UTC')"
    end
  end
end
