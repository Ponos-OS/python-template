.ONESHELL:
.DEFAULT_GOAL := help
.SHELLFLAGS := -ec

## Show this help
help:
	@awk 'BEGIN {FS = ":.*##|## "} /^[a-zA-Z_-]+:.*?## |^## /{if ($$0 ~ /^##/) {print "\n" $$2} else {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}}' $(MAKEFILE_LIST)

## Set up the local dev environment (.venv, deps, .env, git hooks)
init:
	@command -v uv >/dev/null 2>&1 || { echo "uv is required: https://docs.astral.sh/uv/"; exit 1; }
	uv sync
	npm install
	@[ -f .env ] || { [ -f .env.example ] && cp .env.example .env; }
	npx --no-install lefthook install

## Run the app
start:
	uv run python -m src.main

## Run unit tests (src/**/*__test.py)
test:
	@echo "== unit tests: $$(date -u +%FT%TZ) =="
	uv run pytest src/ -v
	@echo "== unit tests done: $$(date -u +%FT%TZ) =="

## Run integration tests (tests/)
integration_test:
	@echo "== integration tests: $$(date -u +%FT%TZ) =="
	uv run pytest tests/ -v
	@echo "== integration tests done: $$(date -u +%FT%TZ) =="

## Check linters
lint_check:
	uv run ruff check .
	uv run ruff format --check .
	uv run flake8
	uv run ty check
	uv run lint-imports
	npx --no-install jscpd

## Apply linters
lint:
	uv run ruff format .
	uv run ruff check --fix .
	uv run flake8
	uv run ty check
	uv run lint-imports
	npx --no-install jscpd

## Build the Docker image
docker_build:
	docker build -t python-template .

## Run the Docker image
docker_run:
	docker run --rm python-template

## Remove caches, venv, and build artefacts
clean:
	rm -rf .venv .pytest_cache .ruff_cache .mypy_cache .import_linter_cache build dist *.egg-info
	find . -type d -name __pycache__ -prune -exec rm -rf {} +

.PHONY: help init start test integration_test lint_check lint docker_build docker_run clean
