.RECIPEPREFIX = >
COMPOSE = docker compose --profile test
RUN_INGESTOR = $(COMPOSE) run --rm tests

ingestor-shell:
> $(RUN_INGESTOR) bash

ingestor-test:
> $(RUN_INGESTOR) mix test

ingestor-lint:
> $(RUN_INGESTOR) sh -c "mix format --check-formatted && mix credo --strict"

ingestor-check: ingestor-lint ingestor-test

.PHONY: ingestor-shell ingestor-test ingestor-lint ingestor-check
