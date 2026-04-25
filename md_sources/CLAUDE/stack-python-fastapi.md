# CLAUDE.md — Python + FastAPI addendum

<!--
  Merged into CLAUDE.md when STACK=python-fastapi.
  Assumed stack: Python 3.11+ + FastAPI 0.110+ + Pydantic v2 + SQLAlchemy 2.0 async + httpx + pytest-asyncio + ruff + mypy
-->

Supplements core CLAUDE.md with FastAPI-specific best practices.

## Commands

```bash
# Environment
uv venv && source .venv/bin/activate
uv pip install -e ".[dev]"

# Dev server
uvicorn app.main:app --reload --port 8000
fastapi dev app/main.py                  # FastAPI CLI (0.111+)

# Tests / lint / types / format
pytest -x                                # pytest-asyncio with asyncio_mode=auto
pytest --cov=app --cov-report=term-missing
ruff check . && ruff format .
mypy app

# Migrations (Alembic with async)
alembic revision --autogenerate -m "<msg>"
alembic upgrade head
```

## Idiomatic patterns (DO)

- **Pydantic v2 models on every boundary** — request, response, settings. `model_config = ConfigDict(from_attributes=True)` for ORM mapping. Validation in the schema, not the route.
- **`Depends()` for everything injectable** — DB session, current user, settings, flags. Trivial overrides via `app.dependency_overrides`.
- **Explicit `response_model=` on every route** — guarantees shape, hides internal fields, correct OpenAPI. Never `return orm_obj` raw.
- **`async def` for I/O; `def` only for pure CPU** — FastAPI runs sync routes in a threadpool. Sync DB drivers in `async def` block the loop.
- **`lifespan` async context manager over `@app.on_event`** — `on_event` deprecated since 0.93. Yield-based handles DB pools, HTTP clients, ML models cleanly.
- **SQLAlchemy 2.0 async session per request** — `AsyncSession` via `Depends(get_db)`, one transaction per request, commit at the boundary.
- **`BackgroundTasks` for fire-and-forget after response** — emails, audit logs, cache warming. For durable work use Celery/arq/dramatiq.
- **Routers grouped by domain in `api/v1/<domain>.py`** — `app.include_router(users.router, prefix="/users", tags=["users"])`. Keep `main.py` thin.
- **Test with `httpx.AsyncClient` against the ASGI app** — `AsyncClient(transport=ASGITransport(app=app), base_url="http://test")`. Faster than `TestClient` for async flows.

## Anti-patterns (AVOID — call out and fix when seen)

- **Sync DB drivers (`psycopg2`, `pymysql`) inside `async def`** — blocks the event loop. Use `asyncpg` / `aiomysql` / SQLAlchemy async engine.
- **Returning ORM models without `response_model`** — leaks columns, breaks lazy-load outside session, no OpenAPI shape. Pass through a Pydantic schema.
- **Auth logic inline in route bodies** — duplicated, untested. Use `Security(get_current_user, scopes=[...])` dependency.
- **Long sync work in `async def` (CPU loops, `time.sleep`, `requests.get`)** — blocks all requests on the worker. Move to `run_in_threadpool`, a worker, or convert to async.
- **Mutating Pydantic models then returning them** — v2 models are immutable-by-convention; mutation breaks validation. Use `model_copy(update=...)`.
- **Catching `Exception` to return generic 500** — hides bugs. Register `@app.exception_handler` per error type.
- **Skipping `response_model_exclude_none=True` on partial responses** — leaks `null` fields.
- **`@app.middleware("http")` for concerns better solved via `Depends`** — middleware runs on every request including static; dependencies scope to routers.

## Test layer hierarchy

Pick the **lightest layer** where the rule reads naturally:

1. **Pure unit tests on services + Pydantic validators** — no app, no DB. Domain logic and schema constraints.
2. **Repository / DB tests with async session fixture** — SQLAlchemy queries, constraints, transactions. Transactional rollback fixture or test container.
3. **Integration via `httpx.AsyncClient` + `dependency_overrides`** — full route, real schemas, mocked external services. Bulk of API tests.
4. **Contract tests against OpenAPI schema** — when consumers depend on the spec; pin with `schemathesis` or snapshot.
5. **E2E with real DB + real broker** — **LAST RESORT.** Reserve for AFTER_COMMIT, webhooks, multi-service flows.

## Tactical testing rules

- One `AsyncClient` fixture per session; one DB transaction per test (rollback in teardown).
- Override `Depends` via `app.dependency_overrides[get_db] = ...`, never monkey-patch globals.
- `pytest-asyncio` with `asyncio_mode = "auto"` in `pyproject.toml` — no `@pytest.mark.asyncio` clutter.
- Snapshot the OpenAPI schema (`/openapi.json`) in CI — breaking changes show in diff.
- Use `respx` or `pytest-httpx` to mock outbound HTTP; never hit real services in tests.

## Stack-specific gotchas

- **`Depends()` results are cached per request** — same dep called twice returns the same value. `use_cache=False` to re-execute.
- **`BackgroundTasks` runs after response in the same process** — if it crashes, response is already sent. No retries. Use a real queue for important work.
- **Pydantic v2 `Field(..., alias="x")` requires `populate_by_name=True`** to accept either name. Easy to miss when migrating from v1.
- **`Response` returned directly skips `response_model` validation and serialization** — useful for streaming, dangerous for typed APIs.
- **`async with AsyncSession()` inside a sync route raises** — pick one paradigm per route.
- **`uvicorn --workers N` doesn't share `lifespan` state** — each worker has its own ML model / pool. Use Redis for cross-worker state.
- **CORS middleware order matters** — `CORSMiddleware` must be added before routers. Misordered = preflight 404.
- **`TestClient` is sync (uses `requests`)** — can't test true async concurrency. Use `httpx.AsyncClient`.
