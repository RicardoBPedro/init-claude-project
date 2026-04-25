# CLAUDE.md — Elixir + Phoenix addendum

<!--
  Merged into CLAUDE.md when STACK=elixir-phoenix.
  Assumed stack: Elixir 1.16+ + Phoenix 1.7+ + Ecto + LiveView + ExUnit + Mox.
-->

Supplements core CLAUDE.md with Elixir/Phoenix-specific best practices.

## Commands

```bash
mix deps.get                                                    # fetch dependencies
mix ecto.setup                                                  # create + migrate + seed
mix ecto.reset                                                  # drop + recreate (dev)
mix phx.server                                                  # run the server
iex -S mix phx.server                                           # with interactive shell
mix test                                                        # full suite (sandboxed Repo)
mix test test/my_app/accounts_test.exs:42                       # single test by line
mix test --only integration                                     # tagged subset
mix format                                                      # format sources
mix credo --strict                                              # opinionated lint
mix dialyzer                                                    # static type analysis
mix sobelow --config                                            # security scan (Phoenix)
```

## Idiomatic patterns (DO)

- **Contexts as bounded modules** — `Accounts.create_user/1`, `Billing.charge/2`. Web layer calls contexts, never `Repo` directly.
- **Ecto changesets for validation + casting** — `User.changeset(%User{}, attrs) |> Repo.insert()`. Never trust raw params.
- **`with` for happy-path railway** — chain tagged tuples cleanly:
  ```elixir
  with {:ok, user}    <- Accounts.fetch(id),
       {:ok, charged} <- Billing.charge(user, amount) do
    {:ok, charged}
  end
  ```
- **Pattern-matching at function heads** — multiple clauses over `case`/`if` inside a body. Reads like a spec.
- **Phoenix LiveView for stateful UI** — server-rendered, reactive, no SPA build. Use `assign/3` and `stream/4` for collections.
- **Explicit OTP supervision tree** — every long-lived process under a Supervisor with documented restart strategy. Crash-only design.
- **`Phoenix.PubSub` for fan-out** — broadcast domain events; LiveViews/channels subscribe. Don't reach for external brokers prematurely.
- **Telemetry for observability** — `:telemetry.execute([:my_app, :user, :created], %{count: 1}, meta)`. Wire into Prometheus/OpenTelemetry.
- **ExUnit + Mox for behaviour mocking** — define `@behaviour`, swap impls per env via `Application.compile_env/3`. `Mox.expect/4` enforces contracts.
- **Tagged tuples on every fallible function** — `{:ok, value} | {:error, reason}`. Avoid raising for expected failures.
- **Doctests** — `## Examples` blocks in `@doc` are run by ExUnit; cheap regression coverage.

## Anti-patterns (AVOID — call out and fix when seen)

- **Business logic inside controllers / LiveViews** — controllers parse + render; LiveView `handle_event` calls `MyApp.Domain.do_thing/1`.
- **GenServer for everything** — most "state" belongs in ETS, the database, or function arguments. Use GenServer when you need a single sequential owner of mutable state.
- **`try / rescue` for control flow** — use `with` + tagged tuples. Reserve `rescue` for third-party-raises cases.
- **`Repo.preload` ad-hoc inside templates / LiveView render** — N+1 queries. Preload upfront: `from u in User, preload: [:posts]`.
- **Module attributes for runtime config** — `@api_key Application.get_env(...)` evaluates at compile time and bakes the value in. Use `Application.compile_env/3` or `Application.get_env/2` at call sites with `runtime.exs`.
- **String interpolation in Ecto queries** — SQL injection. Use parameterized `where: u.email == ^email`.
- **`Enum` on large or infinite collections** — eager. Use `Stream` for pipelines, `Flow`/`Broadway` for parallel work.
- **Calling `Process.sleep/1` in tests** — flake. Use `Process.monitor/1` + `assert_receive`, or `Phoenix.LiveViewTest`'s built-in sync.
- **Deep nesting of `case`** — refactor into multi-clause functions or `with`.
- **Using `nil` as a domain value** — prefer tagged tuples or sum types via atoms.
- **`Repo` calls inside transactions spanning HTTP requests** — keep transactions short; never hold across a network round-trip.

## Test layer hierarchy

1. **Unit (pure functions)** — context helpers, changesets without DB, calculators. No `async: false`, no `Repo`. Default.
2. **Context tests with sandboxed Repo** — `use MyApp.DataCase, async: true`. Ecto SQL Sandbox isolates each test in a transaction; safe parallelism.
3. **LiveView / controller tests** — `Phoenix.ConnTest`, `Phoenix.LiveViewTest`. Routing + render + events without a browser.
4. **End-to-end via Wallaby (or PhoenixTest)** — real browser, real JS. **LAST RESORT.** Only for emergent flows (full sign-up, payment redirect chain).

## Tactical testing rules

- `async: true` on every test module that doesn't touch global state — sandbox makes Repo tests safe.
- Inject time via a `Clock` behaviour mocked with Mox — never call `DateTime.utc_now/0` directly in domain code.
- `Mox.verify_on_exit!` ensures every expected call happened — keeps mocks honest.
- Tag slow / external `@tag :integration`; default `mix test` excludes via `test/test_helper.exs`.
- `assert_receive` over `Process.sleep` for waiting on messages; default 100 ms is plenty.

## Stack-specific gotchas

- **Compile-time vs runtime config** — `Application.get_env/2` at module level captures dev value into prod release. Use `runtime.exs` for prod secrets.
- **Ecto associations require explicit preload** — accessing `user.posts` without preload raises `Ecto.Association.NotLoaded`.
- **LiveView reconnects rebuild assigns** — store source-of-truth in DB/PubSub, not just `socket.assigns`.
- **`GenServer.call` timeouts (default 5 s)** — long-running work blocks callers. Use `cast`, `Task`, or bump timeout intentionally.
- **Releases (`mix release`) don't include `mix` / dev deps** — runtime config from `runtime.exs`, not `config.exs`.
- **`Phoenix.PubSub` is in-node by default** — multi-node fan-out needs `Phoenix.PubSub.PG2` or Redis adapter.
- **Process mailboxes are unbounded** — slow consumer fills RAM. Use back-pressure (`GenStage`, `Broadway`).
- **String vs charlist** — `"foo"` is a binary, `'foo'` is a list of codepoints. Erlang libs often return charlists; convert with `to_string/1`.
- **`Ecto.Multi` for multi-step transactions** — composes safely; better than nested `Repo.transaction(fn -> ...)`.
