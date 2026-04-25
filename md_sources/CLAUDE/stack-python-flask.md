# CLAUDE.md — Python + Flask addendum

<!--
  Merged into CLAUDE.md when STACK=python-flask.
  Assumed stack: Python 3.11+ + Flask 3 + Flask-SQLAlchemy 3 + Werkzeug 3 + pytest-flask + ruff + mypy
-->

Supplements core CLAUDE.md with Flask-specific best practices.

## Commands

```bash
# Environment
uv venv && source .venv/bin/activate
uv pip install -e ".[dev]"

# Dev server
flask --app app run --debug --port 5000
flask --app app shell

# Tests / lint / types / format
pytest -x
pytest --cov=app
ruff check . && ruff format .
mypy app

# DB (Flask-Migrate / Alembic)
flask --app app db migrate -m "<msg>"
flask --app app db upgrade
```

## Idiomatic patterns (DO)

- **Application factory `create_app(config)` pattern** — no module-level `app = Flask(__name__)`. Tests build a fresh app with overridden config.
- **Blueprints per domain** — `users_bp = Blueprint("users", __name__, url_prefix="/users")`. Register in `create_app`.
- **Service layer for business logic** — views call `services.users.create_user(...)`; views handle HTTP only: parse, call, serialize, return.
- **`current_app` and `g` for context-aware access** — never import `app` directly across modules. `g` for per-request state (current user, request id).
- **Flask-SQLAlchemy 3 with `db.session` scoped per request** — teardown commits or rolls back. Use `db.session.execute(select(...))` (2.0 style), not legacy `Model.query`.
- **Werkzeug exceptions for HTTP errors** — `from flask import abort; abort(404, description="...")`. Register `@app.errorhandler(HTTPException)` for JSON.
- **Config via class hierarchy + env vars** — `BaseConfig` → `DevConfig`/`ProdConfig`/`TestConfig` via `app.config.from_object(...)`. Secrets from env.
- **`pytest-flask` `app` and `client` fixtures** — `client = app.test_client()`, push `app_context()` for DB/CLI tests.
- **CLI commands via `@app.cli.command`** — wrap in `with app.app_context()` if hitting the DB outside the request cycle.

## Anti-patterns (AVOID — call out and fix when seen)

- **`app = Flask(__name__)` at module top level** — config frozen at import time, hostile to testing. Use `create_app()`.
- **`request.get_json(force=True)` everywhere** — bypasses Content-Type checks. Use default `force=False` and validate.
- **Hitting the DB in CLI scripts without `app.app_context()`** — raises `RuntimeError: Working outside of application context`. Wrap explicitly.
- **`CORS(app, origins="*")` in production** — leaks credentials. Pin to known origins per environment.
- **Default `SECRET_KEY` or empty string in prod** — sessions become forgeable. Fail fast: `assert app.config["SECRET_KEY"]` in `create_app`.
- **Catching `Exception` in views to return 500** — hides stack traces. Let the error handler do it; log with `current_app.logger.exception`.
- **Direct `Model.query` chains across modules** — couples callers to ORM. Wrap reads in `repositories/` or model classmethods.
- **Storing user state in module globals** — Flask runs multiple workers; globals don't sync. Use session, DB, or cache.
- **Mixing sync Flask with `asyncio.run()` per request** — fights the WSGI model. Use ASGI (Quart) or a worker.

## Test layer hierarchy

Pick the **lightest layer** where the rule reads naturally:

1. **Pure unit tests on services and validators** — no app context, no DB. Domain rules read fastest here.
2. **DB tests with `app_context()` + transactional rollback** — Flask-SQLAlchemy 3 + nested transactions in fixtures. Constraints, queries, repositories.
3. **Integration via `app.test_client()`** — full request cycle, JSON in/out, auth, status codes. Bulk of route tests.
4. **CLI tests via `app.test_cli_runner()`** — for `flask <command>` scripts.
5. **E2E via Playwright or live server** — **LAST RESORT.** Real browser flows, payment redirects, multi-page journeys.

## Tactical testing rules

- One `app` fixture (session scope) + one `client` fixture (function scope) — standard pytest-flask layout.
- Wrap each test in a transaction and roll back on teardown — never `db.drop_all()` between tests (slow, masks isolation bugs).
- Override config in tests via `create_app(TestConfig)`, not by mutating `app.config` mid-test.
- Mock external HTTP with `responses` or `pytest-httpserver`; never hit real APIs in CI.
- Assert response JSON shape, not just status codes — schema regressions are silent killers.

## Stack-specific gotchas

- **`g` is per-request, not per-session** — don't store user prefs there. Use `session` (signed cookie) or DB.
- **`request` object is a proxy** — falsy checks like `if request:` always pass. Use `request.is_json`, `request.method`.
- **Flask-SQLAlchemy 3 still supports `Model.query` but new code must use `db.session.execute(select(Model))`** for SQLAlchemy 2.0 compatibility.
- **`@app.before_first_request` removed in Flask 2.3+** — use `with app.app_context():` block at startup or the app factory.
- **`send_file` with user-supplied paths is path-traversal bait** — use `send_from_directory` and validate.
- **`session` is signed but not encrypted** — readable by the user. Never put secrets in it.
- **Werkzeug's dev server is not for production** — gunicorn/uwsgi/waitress only.
- **`debug=True` enables the interactive debugger** — RCE if exposed. Never set via env in shared environments.
