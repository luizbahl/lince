defmodule Ingestor.ClickhouseRepo.Migrations.CreateCompanyChanges do
  use Ecto.Migration

  def change do
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
