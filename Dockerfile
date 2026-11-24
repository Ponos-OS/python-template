# --------------------------------------------------------------
# ---------- Builder Stage -------------------------------------
# --------------------------------------------------------------
FROM python:3.12-slim-bookworm AS builder
WORKDIR /app
COPY --from=ghcr.io/astral-sh/uv:0.11.13 /uv /uvx /usr/local/bin/

ENV UV_PROJECT_ENVIRONMENT=/app/.venv
# `copy` link mode: safe across bind mounts / different filesystems.
ENV UV_LINK_MODE=copy
# Compile .py to .pyc right after installation.
ENV UV_COMPILE_BYTECODE=1
# Never let uv download a different Python at build time.
ENV UV_PYTHON_DOWNLOADS=never

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-install-project --no-dev
COPY src ./src
RUN uv sync --frozen --no-dev

# --------------------------------------------------------------
# ---------- Runtime Stage -------------------------------------
# --------------------------------------------------------------
FROM python:3.12-slim-bookworm AS runtime
WORKDIR /app
ENV PATH="/app/.venv/bin:${PATH}"
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
RUN groupadd --system --gid 1000 app \
    && useradd --system --uid 1000 --gid 1000 --home /app --no-create-home app

COPY --from=builder --chown=app:app /app/.venv /app/.venv
COPY --from=builder --chown=app:app /app/src /app/src
COPY --from=builder --chown=app:app /app/pyproject.toml /app/pyproject.toml

USER app

# Once a server is added: EXPOSE its port and add a HEALTHCHECK.
CMD ["python", "-m", "src.main"]
