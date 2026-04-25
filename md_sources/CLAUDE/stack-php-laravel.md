# CLAUDE.md — PHP / Laravel addendum

<!--
  Merged into CLAUDE.md when STACK=php-laravel.
  Assumed stack: Laravel 11+, PHP 8.3+, Eloquent, PHPUnit/Pest, Pint, PHPStan/Larastan.
-->

Supplements core CLAUDE.md with Laravel-specific best practices.

## Commands

```bash
php artisan serve                          # dev server
php artisan migrate                        # run migrations
php artisan migrate:fresh --seed           # rebuild + seed (dev only)
php artisan make:model Post -mfsc          # model + migration + factory + seeder + controller
php artisan make:request StorePostRequest  # form request
php artisan make:policy PostPolicy --model=Post
php artisan route:list                     # inspect routes
php artisan queue:work                     # background workers
vendor/bin/phpunit --filter=PostTest       # single test (or vendor/bin/pest)
vendor/bin/pint                            # format
vendor/bin/phpstan analyse --level=8       # static analysis (Larastan)
composer require <pkg>                     # add dependency
```

## Idiomatic patterns (DO)

- **`declare(strict_types=1);` at the top of every PHP file** — type juggling bugs disappear when the engine refuses coercion.
- **Form Requests for validation + auth** — `make:request` centralizes `rules()`, `authorize()`, `messages()`. Controllers stay clean.
- **Eloquent accessors/mutators with `Attribute::make`** — modern (Laravel 9+) replacement for `getXAttribute`. `protected function name(): Attribute { return Attribute::make(get: fn ($v) => ucfirst($v)); }`.
- **API Resources for response shape** — `UserResource::collection($users)` decouples DB columns from JSON contract.
- **Constructor DI via the service container** — typed dependencies; no `app('foo')` lookups inside business logic.
- **Policies for authorization** — `$this->authorize('update', $post)` in controllers; `Gate::define` for non-model rules.
- **Queue jobs over inline async** — `dispatch(new ProcessPayment($order->id))`; idempotent, pass IDs not models.
- **Database transactions in tests via `RefreshDatabase`** — fast rollback per test. `use RefreshDatabase;` in the test class.
- **`config()` reads, never `env()` outside config files** — `env()` returns `null` once config is cached in production.

## Anti-patterns (AVOID — call out and fix when seen)

- **Business logic in controllers** — controllers route + delegate. Extract to action classes (`App\Actions\CreatePost`) or services.
- **Eloquent inside Blade views** — `{{ $post->author->name }}` without eager-loading triggers N+1. Use `Post::with('author')->get()` and `beyondcode/laravel-query-detector`.
- **`Auth::user()` everywhere** — global state, hard to test. Inject `Request $request` and call `$request->user()`.
- **Raw queries with interpolation** — `DB::select("SELECT * FROM users WHERE id = $id")` is SQL injection. Use bindings: `DB::select('... WHERE id = ?', [$id])`.
- **Jobs serializing closures or full models** — `dispatch(fn() => ...)` and `new Job($user)` break on schema drift and bloat payloads. Pass scalar IDs, refetch in `handle()`.
- **Mass-assignment without `$fillable`** — `User::create($request->all())` is privilege-escalation. Define `$fillable` and use `validated()`.
- **Calling `->save()` after `->update()`** — `update()` already persists; double-save signals confusion about Eloquent lifecycle.
- **Service Providers as a junk drawer** — singletons for everything; cyclic deps. Bind only what needs custom resolution.

## Test layer hierarchy

1. **Unit (no DB, no framework boot)** — pure PHP classes (services, value objects, calculators). Fast (<10ms each). PHPUnit/Pest with no `RefreshDatabase`.
2. **Feature with `RefreshDatabase`** — boot framework, hit routes, assert DB state. `$this->postJson('/api/posts', ...)->assertCreated();` Most tests live here.
3. **Browser via Laravel Dusk** — **LAST RESORT.** Real Chrome via ChromeDriver. Use only for genuine JS-driven flows (Livewire, Inertia). Slow, flaky-prone.

## Tactical testing rules

- `Http::fake()` for outbound HTTP; `Queue::fake()` and `Bus::fake()` for jobs; `Mail::fake()` for mail. Assert dispatched, don't run.
- `Storage::fake('s3')` for filesystem assertions; never hit real S3.
- Time: `Carbon::setTestNow(...)` or `$this->travelTo(...)`; reset in `tearDown`.
- Database assertions via `assertDatabaseHas` / `assertDatabaseMissing`; avoid Eloquent's cache (`->fresh()` when re-querying).
- Disable seeding inside test setup unless seed data is the rule under test.

## Stack-specific gotchas

- **`config:cache` and `env()`** — once cached in production, `env()` returns `null` outside config files. Always read via `config('services.foo.key')`.
- **Eloquent's `boot()` static side effects** — model events fire on every save. Non-trivial logic there causes hidden coupling. Use observers or events sparingly.
- **Soft deletes + unique indexes** — MySQL unique constraints don't see `deleted_at`. Use a partial index or include `deleted_at` in the unique key.
- **Queue `tries` and `backoff`** — set per job; without them, transient failures DDoS dependencies. `public int $tries = 3; public array $backoff = [10, 30, 120];`.
- **Eager loading + `select()`** — `User::select('id')->with('posts')` drops the FK and `posts` come back empty. Always include the FK column.
- **`firstOrCreate` is not atomic** — races under load. Wrap in a transaction with `lockForUpdate()` or use unique index + `INSERT ... ON DUPLICATE KEY UPDATE`.
- **PHP 8.3 readonly properties** — great for DTOs, but cannot be modified after construction even from inside the class.
- **`composer.lock` must be committed** — and `composer install` (not `update`) in CI / production.
