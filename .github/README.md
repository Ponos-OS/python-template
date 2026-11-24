# python-template

A template for Python projects.

## Requirements

- [`uv`](https://docs.astral.sh/uv/)
- [Node.js](https://nodejs.org/) (dev tooling only: `jscpd`, `lefthook`)
- [Docker](https://www.docker.com/) (optional)

## Usage

```shell
make init   # deps, .env, git hooks
make start  # run src/main.py
make help   # all commands
```

## Docker

```shell
make docker_build
make docker_run
```

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the project layout and conventions.
