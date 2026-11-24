# Contributing to `python-template`

This document covers the project layout and the testing philosophy so you know **which kind of test to write for what**.

## How to Start on Local Machine

- [`uv`](https://docs.astral.sh/uv/)
- [Node.js](https://nodejs.org/) for `jscpd` and `lefthook`
- [Docker](https://www.docker.com/) only to build the production image

```shell
make init
make start
```

`make init` installs the Python and Node dependencies, copies `.env.example` to `.env` and installs the git hooks.

## Project Structure

```
python-template/
├── src/                      # All production code
│   ├── __init__.py
│   ├── main.py               # Entrypoint
│   └── main__test.py         # Unit test, colocated with the file it covers
├── tests/                    # Integration tests only
│   ├── conftest.py
│   └── test_main.py
├── .github/
│   ├── README.md
│   └── CONTRIBUTING.md
├── .claude/settings.json     # Blocks `git commit` when unit tests fail
├── .pre-commit-config.yaml   # The checks: ruff, ty, import-linter, flake8-aaa, jscpd, tests, conventional commits
├── lefthook.yml              # Git hook runner; calls the pre-commit checks per stage
├── .jscpd.json               # Copy/paste detection config
├── .flake8                   # flake8-aaa config
├── Dockerfile, compose.yml
├── Makefile                  # Single entry point for every command
├── package.json              # Node dev tooling only (jscpd, lefthook)
├── pyproject.toml            # Dependencies, pytest, ruff, ty, import-linter config
└── uv.lock                   # Committed lockfile
```

- **Unit tests** are colocated with the source they cover, using the `*__test.py` suffix, and live under `src/`. `make test` runs `uv run pytest src/ -v`.
- **Integration tests** live only under `tests/` and run via `make integration_test`.
- **All production code lives in `src/`.** Nothing in `src/` may import from `tests/`.

## Git Hooks

[`lefthook`](https://github.com/evilmartians/lefthook) runs the hooks, the checks themselves are defined in `.pre-commit-config.yaml`:

| Stage        | What runs                                                                    |
| ------------ | ---------------------------------------------------------------------------- |
| `pre-commit` | `ruff` lint + format, file hygiene, `ty`, `import-linter`, `flake8-aaa`, `jscpd` |
| `commit-msg` | [Conventional Commits](https://www.conventionalcommits.org/) check           |
| `pre-push`   | `ruff` on all files, unit tests, integration tests                           |

Commit messages must look like `feat: add x`, `fix(api): handle y`, `chore: bump z`.

## Testing Philosophy

1. Unit tests:
   - **Question:** _Does this piece of Python behave correctly in isolation?_
   - Fast, hermetic, no network.
   - Add them generously, they are cheap.
2. Integration tests:
   - **Question:** _Does the app actually work end-to-end?_
   - Purposefully thin: one happy path per entrypoint plus the documented error paths.
   - Add one when introducing a new entrypoint or when a bug regressed the contract.

## Design & Code Philosophy

1. Simpler is better - **do not overcomplicate**.
2. Prefer **early returns over nested conditionals**.
3. Use pytest.
   - Use [AAA (Arrange, Act, Assert) style of writing test](https://stackoverflow.com/tags/arrange-act-assert/info).
   - [`flake8-aaa`](https://pypi.org/project/flake8-aaa/) (`make lint_check`, config in `.flake8`) checks AAA structure. It identifies the Act block semantically: a `result = ...` assignment, `with pytest.raises(...)`, or a `# act` comment. An assignment to any other name is **not** recognized and fails `AAA01`; name the variable `result` or add a trailing `# act` comment.
   - **Known gap:** it only checks `def test_...`, not `async def test_...`, so async tests are silently skipped. Review them for AAA by eye.
4. IMPORTANT: Avoid overly defensive programming; avoid `insistence` checks; only manage exceptions when necessary.
5. Use `uv`; ALWAYS `uv run xxx` NEVER `python3 xxx`.
6. Use latest version of libraries and idiomatic approaches as of today.
7. `pytest` resolving `src.*` imports in `*__test.py` files needs `[tool.pytest.ini_options] pythonpath = ["."]` in `pyproject.toml`; without it every colocated unit test fails to collect with `ModuleNotFoundError: No module named 'src'`.
8. This is an application, not a distributable library, so `[tool.uv] package = false` stays set in `pyproject.toml`; otherwise `uv sync` tries to build and install the project itself.
9. **Barrel imports are enforced** via [`import-linter`](https://import-linter.readthedocs.io/). Every package has an `__init__.py` that re-exports its public API and nothing else, and callers import from the package (`from src.utils import Settings`), never from the submodule that defines it (`from src.utils.config import Settings`). Add one `protected` contract per barrel package in `pyproject.toml`:
    ```toml
    [[tool.importlinter.contracts]]
    name = "src.utils internals are private"
    type = "protected"
    protected_modules = ["src.utils.**"]
    allowed_importers = ["src.utils", "src.utils.**"]
    ```
    `**` matches at any depth (`*` only one level), so sibling submodules and colocated `*__test.py` files are covered by the same contract. A new file in an existing barrel package needs no config change.
10. Copy/paste is checked by `jscpd` over `src` and `tests`; extract shared code instead of raising the threshold in `.jscpd.json`.
