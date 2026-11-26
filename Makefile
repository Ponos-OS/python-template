.ONESHELL:
.DEFAULT_GOAL := help
.SHELLFLAGS := -ec

# Tracked and new text files, NUL separated.
TEXT_FILES = git grep --untracked -Ilz -e ''
YAML_FILES = $(TEXT_FILES) -- '*.yml' '*.yaml'
TOML_FILES = $(TEXT_FILES) -- '*.toml'
# The fixers matter for everything else, such as Markdown, YAML, JSON, the Makefile and the Dockerfile.
WHITESPACE_FIXERS = end-of-file-fixer trailing-whitespace-fixer

## Show this help message
help:
	@echo "Makefile targets:"
	@targets="$$(grep -E '^[a-zA-Z_-]+:' $(MAKEFILE_LIST) | cut -d: -f1)"; \
	width="$$(printf '%s\n' "$$targets" | awk '{ if (length > max) max = length } END { print max }')"; \
	awk -v width="$$width" ' \
		/^## / { description = substr($$0, 4); next } \
		/^[a-zA-Z_-]+:/ && description { \
			target = $$1; \
			sub(/:.*/, "", target); \
			printf "  make \033[36m%-*s\033[0m - %s\n", width, target, description; \
			description = ""; \
		} \
	' $(MAKEFILE_LIST)

## Set up the local dev environment (.venv, deps, .env, git hooks)
init:
	@command -v uv >/dev/null 2>&1 || { echo "uv is required: https://docs.astral.sh/uv/"; exit 1; }
	uv sync
	npm install
	@[ -f .env ] || { [ -f .env.example ] && cp .env.example .env; }
	npx --no-install lefthook install
	# git push opens the SSH connection before pre-push runs; keep it alive while slow tests finish.
	git config core.sshCommand > /dev/null || git config core.sshCommand "ssh -o ServerAliveInterval=30"

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

## Format the code
format:
	$(YAML_FILES) | xargs -0 uv run check-yaml
	$(TOML_FILES) | xargs -0 uv run check-toml
	# A fixer exits 1 after changing a file, so only a second failure is an error.
	for fixer in $(WHITESPACE_FIXERS); do
		$(TEXT_FILES) | xargs -0 uv run $$fixer || $(TEXT_FILES) | xargs -0 uv run $$fixer
	done
	uv run taplo format
	uv run ruff check --fix .
	# Colored output queries the terminal's background; inside a git hook the reply leaks into the shell.
	npx --no-install ast-grep scan --color never -U src tests
	uv run ruff format .

## Check formatting
format_check:
	$(YAML_FILES) | xargs -0 uv run check-yaml
	$(TOML_FILES) | xargs -0 uv run check-toml
	# The fixers have no check mode, so they run on a throwaway copy.
	copy="$$(mktemp -d)"
	trap 'rm -rf "$$copy"' EXIT
	$(TEXT_FILES) | tar --null -T - -cf - | tar -xf - -C "$$copy"
	for fixer in $(WHITESPACE_FIXERS); do
		$(TEXT_FILES) | (cd "$$copy" && xargs -0 uv run --project "$(CURDIR)" $$fixer)
	done
	uv run taplo format --check
	uv run ruff format --check .
	npx --no-install ast-grep scan src tests

## Check linters
lint_check: format_check
	uv run ruff check .
	uv run flake8
	uv run ty check
	uv run lint-imports
	npx --no-install jscpd

## Apply linters
lint: format
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

.PHONY: help init start test integration_test format format_check lint_check lint docker_build docker_run clean
