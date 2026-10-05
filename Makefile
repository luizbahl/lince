.RECIPEPREFIX = >
COMPOSE = docker compose --profile test
RUN_INGESTOR = $(COMPOSE) run --rm tests

ingestor-shell:
> $(RUN_INGESTOR) bash

ingestor-deps:
> $(RUN_INGESTOR) mix deps.get

ingestor-test:
> $(RUN_INGESTOR) mix test

ingestor-lint:
> $(RUN_INGESTOR) sh -c "mix format --check-formatted && mix compile --warnings-as-errors && mix credo --strict"

ingestor-check: ingestor-deps ingestor-lint ingestor-test

.PHONY: ingestor-shell ingestor-deps ingestor-test ingestor-lint ingestor-check
