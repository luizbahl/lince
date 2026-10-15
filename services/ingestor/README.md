# Ingestor

Loads Receita Federal's monthly open CNPJ data into ClickHouse and detects what changed for each
company from one month to the next. Part of [Lince](../../README.md).

## How it works

```mermaid
flowchart LR
    ZIP[Empresas*.zip] -->|import_companies| C[(companies)]
    C -->|detect_company_changes| CC[(company_changes)]
```

1. **Import** (`Ingestor.import_companies/1`): unzips an `Empresas*.zip`, stream-parses the
   ISO-8859-1 CSV into UTF-8 and inserts it into `companies` in batches of 10,000 rows. Files of
   several GB are processed with constant memory.
2. **Detect changes** (`Ingestor.detect_company_changes/1`): compares a month with the month
   before and stores one row per change in `company_changes`. Both months must be imported.

Both operations are idempotent: running them again for the same month replaces the result.

## Usage

There is no HTTP API yet; call the facade from `iex -S mix`:

```elixir
Ingestor.import_companies(%{
  zip_path: Path.expand("~/lince-data/2026-09/Empresas0.zip"),
  reference_month: ~D[2026-09-01]
})
#=> {:ok, %Ingestor.Pipeline.ImportCompanies.Output{inserted: ...}}

Ingestor.detect_company_changes(%{reference_month: ~D[2026-09-01]})
#=> {:ok, %Ingestor.Pipeline.DetectCompanyChanges.Output{changes: ...}}
```

Errors come back as `{:error, type, detail}`:

| Type | When |
|---|---|
| `:invalid_input` | `detail` is the changeset (e.g. file not found, month not on day 1) |
| `:extract_failed` | the zip could not be extracted |
| `:load_failed` | a CSV line could not be parsed or inserted |
| `:month_not_imported` | `detail` is the month (current or previous) missing from `companies` |
| `:detect_failed` | the change detection query failed |

## Data model

**`companies`**: one row per CNPJ root per reference month, as published by Receita Federal.

**`company_changes`**: one row per change found in a reference month.

| change_type | Meaning | field / previous_value / current_value |
|---|---|---|
| `created` | CNPJ root appeared this month | empty |
| `removed` | CNPJ root disappeared this month | empty |
| `updated` | a field changed | field name, old and new value (as strings) |

Both tables are ordered by `cnpj_root`, so "history of one company" is a fast lookup.

## Design decisions

- **The diff runs inside ClickHouse.** Each month has ~60M companies; moving two months to Elixir
  to compare them would mean ~120M rows over HTTP. A single `INSERT ... SELECT` does it in place.
- **`GROUP BY cnpj_root` instead of `FULL OUTER JOIN`.** A join holds one whole month in memory
  as a hash table; an aggregation can spill to disk.
- **`company_changes` is a `MergeTree` partitioned by month, replaced with `DROP PARTITION`.**
  A re-run can find *fewer* changes than before; a `ReplacingMergeTree` would only overwrite rows
  with the same key and keep the stale ones.
- **Railway-style pipelines** (`lib/ingestor/pipeline/`): each step returns `{:ok, params}` or
  `{:error, type, detail}` and the first error skips the remaining steps.

## Development

Requires the infrastructure from the repository root (`docker compose up -d`). Tests, format and
Credo run inside the `tests` container:

```bash
docker compose run --rm tests bash
mix test
mix format --check-formatted
mix credo --strict
```
