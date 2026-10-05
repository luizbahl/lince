# Lince — project context

Lince continuously monitors Brazilian companies (CNPJ) and alerts users when their registry data
changes (status, legal name, partners, economic activity). It is a portfolio project meant to be
read by recruiters, so code quality, tests and documentation matter as much as features.

## Conventions

- **All code, table/column names, commits and docs are in English.** Brazilian domain terms with
  no direct translation (e.g. CNPJ) keep their original name.
- Conversation with the author can be in Portuguese.
- Commits follow Conventional Commits (`feat(ingestor): ...`, `chore: ...`, `docs: ...`).
- The author is learning: explain the *why* of each step and prefer small, verifiable steps.
- Zero infrastructure budget: everything must run locally; the AWS deploy pipeline is written and
  documented but not active.

## Architecture

Monorepo with 4 independent Mix projects (not an umbrella) under `services/`, communicating
through **direct HTTP calls** (Req). Each service owns its data.

| Service | Port | Responsibility | Database |
|---|---|---|---|
| portal | 4000 | Phoenix LiveView dashboard, multi-tenant; reads other services via HTTP | — |
| monitor | 4001 | Periodic checks of watched CNPJs (Oban), change history | Postgres + TimescaleDB (`Monitor.Repo`, `priv/repo/migrations`) |
| ingestor | 4002 | Downloads and processes Receita Federal monthly open data into ClickHouse; month-over-month diff | ClickHouse (`Ingestor.ClickhouseRepo`, `priv/clickhouse_repo/migrations`) |
| notifier | 4003 | Webhooks and e-mail delivery with retries | — |

Observability: PromEx → Prometheus → Grafana.

## Local environment

- Ubuntu, Erlang/OTP 29, Elixir 1.20.4 (installed with mise).
- `docker-compose.yml` at the repo root. `docker compose up -d` starts the infra:
  - Postgres + TimescaleDB: `localhost:54320` (postgres/postgres)
  - ClickHouse: `localhost:8123` (lince/lince), database `lince` (dev) and `lince_test` (test)
  - Prometheus: `localhost:9090`; Grafana: `localhost:3000` (admin/admin)
- **ClickHouse is pinned to 24.8 LTS** because the dev machine's CPU has no AVX/AVX2 (newer images
  crash with "Illegal instruction"). Do not bump it.
- Tests, format and Credo run inside the `tests` container (profile `test`):
  `docker compose run --rm tests bash`, then `mix test`, `mix format`, `mix credo --strict`.
  The container mounts the whole repo at `/app`; working dir is `/app/services/ingestor`.
  Inside containers, DB hosts come from `CLICKHOUSE_HOST` / `POSTGRES_HOST` env vars.
- Raw data files live outside the repo in `~/lince-data/<YYYY-MM>/`.

## Data source

Receita Federal open CNPJ data: `https://arquivos.receitafederal.gov.br/dados/cnpj/dados_abertos_cnpj/<YYYY-MM>/`
— zipped CSVs, `;` separator, ISO-8859-1 encoding. Files: `Empresas0..9`, `Estabelecimentos0..9`,
`Socios0..9`, plus lookup tables (CNAEs, municipalities, legal natures...).

`companies` table (ClickHouse, MergeTree, `PARTITION BY reference_month ORDER BY (cnpj_root, reference_month)`):

| Receita field | Column |
|---|---|
| cnpj_basico | cnpj_root |
| razao_social | legal_name |
| natureza_juridica | legal_nature_code |
| qualificacao_responsavel | responsible_qualification_code |
| capital_social | share_capital (comma decimal in source) |
| porte_empresa | size_code |
| ente_federativo_responsavel | federative_entity |

## Current status / next steps

- [x] Local infra with Docker Compose
- [x] ingestor project with `Ingestor.ClickhouseRepo` (ecto_ch) and `companies` migration
- [ ] `tests` container working (`mix test`, format, Credo)
- [ ] Rewrite README with English as the main language (short Portuguese section at the end, explain what a CNPJ is)
- [ ] ingestor: stream-parse `Empresas*.zip` (NimbleCSV, ISO-8859-1 → UTF-8) and batch-insert into ClickHouse
- [ ] ingestor: month-over-month change detection
- [ ] then monitor, notifier, portal, CI (GitHub Actions), deploy pipeline