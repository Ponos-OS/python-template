# Contributing

This document covers the project layout and the testing philosophy so you know **which kind of test to write for what**.

## How to Start on Local Machine

```shell
make init
make start
```

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
├── .pre-commit-config.yaml   # Git hooks
├── lefthook.yml              # Git hook runner; calls the pre-commit checks per stage
├── sgconfig.yml              # ast-grep config
├── ast-grep/rules/           # Custom lint rules
├── .gitattributes            # LF line endings
├── .jscpd.json               # Copy/paste detection config
├── .flake8                   # flake8-aaa config
├── .taplo.toml               # TOML formatter config (also read by the "Even Better TOML" editor extension)
├── Dockerfile, compose.yml
├── Makefile                  # Single entry point for every command
├── package.json              # Node dev tooling only (ast-grep, jscpd, lefthook)
├── pyproject.toml            # Dependencies, pytest, ruff, ty, import-linter config
└── uv.lock                   # Committed lockfile
```

## Testing Philosophy

1. Unit tests:
   - **Question:** _Does this piece of Python behave correctly in isolation?_
   - Colocated with the source they cover, using the `*__test.py` suffix, and live under `src/`. `make test` runs `uv run pytest src/ -v`.
   - Fast, hermetic, no network.
   - Add them generously, they are cheap.
2. Integration tests:
   - **Question:** _Does the app actually work end-to-end?_
   - Live only under `tests/` and run via `make integration_test`.
   - Purposefully thin: one happy path per entrypoint plus the documented error paths.
   - Add one when introducing a new entrypoint or when a bug regressed the contract.

## Design & Code Philosophy

1. Simpler is better - **do not over-engineer**.
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
