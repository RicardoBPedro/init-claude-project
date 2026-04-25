# CLAUDE.md — Python + Django addendum

<!--
  Merged into CLAUDE.md when STACK=python-django.
  Assumed stack: Python 3.11+ + Django 5 + DRF + pytest-django + ruff + mypy + django-environ
-->

Supplements core CLAUDE.md with Django-specific best practices.

## Commands

```bash
# Environment
uv venv && source .venv/bin/activate   # or: python -m venv .venv
uv pip install -r requirements.txt     # or: pip install -e ".[dev]"

# Dev server / shell
python manage.py runserver
python manage.py shell_plus              # django-extensions

# Migrations
python manage.py makemigrations <app>
python manage.py migrate
python manage.py showmigrations

# Tests / lint / types / format
pytest                                   # uses pytest-django
pytest -k test_name -x --reuse-db
ruff check . && ruff format .
mypy .                                   # with django-stubs plugin
```

## Idiomatic patterns (DO)

- **Settings split (`base.py` + `dev.py` + `prod.py` + `test.py`)** — `DJANGO_SETTINGS_MODULE` selects. Never branch on `DEBUG` for config.
- **Custom managers + querysets for domain reads** — `User.objects.active().for_org(org)` over scattered `.filter(is_active=True, org=org)`.
- **Service layer for cross-model logic** — `services/billing.py` with pure functions; views handle HTTP only.
- **`select_related` / `prefetch_related` by default on list views** — treat unexpected query counts as bugs (`django-debug-toolbar`).
- **Migrations small, reversible, reviewed** — one logical change per migration; always implement `RunPython.reverse_code`. Squash per release.

## Anti-patterns (AVOID — call out and fix when seen)

- **`Model.objects.all().filter(...)` chains crossing modules** — leaks ORM to callers. Wrap in a manager/queryset method.
- **Signals (`post_save`) for in-domain logic** — invisible side effects, fire on every save including fixtures. Reserve for cross-domain decoupling; prefer explicit service calls.
- **`ForeignKey(..., on_delete=models.CASCADE)` reflexively** — `PROTECT` / `SET_NULL` are often safer for audit data.
- **Skipping `unique_together` / `UniqueConstraint`** — race conditions create duplicates. Constrain at DB layer, not in `clean()`.

## Test layer hierarchy

Pick the **lightest layer** where the rule reads naturally:

1. **Pure unit / service tests** — `services/` and `selectors/` with no DB. Fastest, run on every save.
2. **Model + queryset tests (`@pytest.mark.django_db`)** — invariants, custom managers, constraints. Use `--reuse-db`.
3. **View tests via `Client` / DRF `APIClient`** — auth, permissions, status codes, serializer shapes. One per endpoint, not per branch.
4. **E2E via Playwright / pytest-playwright** — **LAST RESORT.** Reserve for genuine cross-page flows (checkout, signup).

## Tactical testing rules

- Use `factory_boy` factories, never raw `Model.objects.create()` in tests.
- `freezegun` or `time-machine` for time; never `datetime.now()` in domain code (inject a clock).
- Assert query count with `django_assert_num_queries` on list endpoints — locks in N+1 fixes.
- Migrations get a smoke test: `pytest --create-db` in CI on the migration commit.

## Stack-specific gotchas

- **`auto_now=True` fires on every save** including data migrations. Use `update_fields` to avoid clobbering.
- **`bulk_create` skips `save()`, signals, `auto_now`** — use `update_or_create` loop when invariants matter.
- **`QuerySet` is lazy** — doesn't hit DB until iterated. Slicing inside a loop re-queries each time.
- **`@transaction.atomic` doesn't roll back side effects** — emails, Celery, external APIs fire even on rollback. Use `transaction.on_commit()`.
- **`get_or_create` is not atomic without a unique constraint** — race window creates duplicates. Pair with `UniqueConstraint`.
- **Test DB is created per session** — `--reuse-db` skips creation; drop after schema changes or use `--create-db` once.
- **Django 5 async views are partial** — ORM is sync; use `sync_to_async` at the boundary or stay sync end-to-end.
