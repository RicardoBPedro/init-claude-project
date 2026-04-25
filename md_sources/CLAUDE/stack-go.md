# CLAUDE.md — Go addendum

<!--
  Merged into CLAUDE.md when STACK=go.
  Assumed stack: Go 1.22+ with stdlib + golangci-lint + testcontainers-go.
-->

Supplements core CLAUDE.md with Go-specific best practices.

## Commands

```bash
go build ./...                                                  # build all packages
go test ./...                                                   # full suite
go test -race -count=1 ./...                                    # race detector, no cache
go test -run TestFooBar ./internal/foo                          # single test
go test -cover -coverprofile=cover.out ./... && go tool cover -func=cover.out
golangci-lint run --config .golangci.yml                        # strict lint
go vet ./...                                                    # built-in vet
gofmt -l -w .                                                   # format in place
go mod tidy && go mod verify                                    # dependency hygiene
go run ./cmd/<binary>                                           # run a main package
```

## Idiomatic patterns (DO)

- **Wrap errors with `%w`** — `fmt.Errorf("load user %s: %w", id, err)`. Preserves chain for `errors.Is`/`errors.As`.
- **`context.Context` first arg** on any public method doing I/O, DB, RPC, or anything cancelable.
- **Define interfaces at the consumer**, not the producer. Small (1-3 methods) — `io.Reader` not `BigService`.
- **`errors.Is` / `errors.As` over `==`** — works through wrapping.
- **Table-driven tests with `t.Run`** — named subtests, scoped failures, `-run TestFoo/case_name`.
- **`log/slog` for structured logs** — `slog.Info("user login", "user_id", id, "ip", ip)`. JSON in prod, text in dev.
- **Channel ownership: sender closes, never receiver.** Closed-by-receiver panics. Document ownership.
- **Layout: `cmd/<binary>/main.go` thin entrypoints + `internal/` for non-exported.** `pkg/` only for external consumers.
- **Pass `*sync.Mutex` (or embed in unexported struct), never copy.** `go vet` catches most.

## Anti-patterns (AVOID — call out and fix when seen)

- **`panic` for control flow** — return `error`. Reserve panic for unrecoverable invariants.
- **Goroutines without cancellation** — every `go func()` needs `ctx` or `done` channel, or it leaks. Inspect with `goleak`.
- **`interface{}` / `any` without immediate type assertion** — use generics or concrete types. `any` is a smell outside reflection/encoding.
- **`init()` side effects** — global state, network calls, registration. Hard to test. Use explicit constructors from `main`.
- **`util` / `helpers` / `common` packages** — kitchen sinks. Organize by domain (`billing`, `auth`, `inventory`).
- **`time.Sleep` in tests** — flake factory. Inject a clock (`clockwork`, `quartz`) or use `synctest` (Go 1.24+).
- **Empty `for {}` / `select {}` busy loops without backoff** — burn CPU. Use timers or context.
- **Mixing `log` (stdlib v1) and `slog`** — pick one. `slog` is the Go 1.21+ default.
- **Returning concrete types behind a pointer when value semantics fit** — `*string`, `*int` for "optional" — use `sql.NullString` or `Optional[T]`.

## Test layer hierarchy

1. **Unit (table-driven)** — pure functions and small structs. No I/O, no goroutines, no clock. `testing` + `testify/require` if needed.
2. **Integration** — `testcontainers-go` for real Postgres/Redis, `httptest.NewServer` for HTTP. Tag `//go:build integration` so unit runs stay fast.
3. **End-to-end** — full binary spawned, real network. **LAST RESORT.** Only for emergent behaviour (auth chain, full request lifecycle, deployment smoke).

## Tactical testing rules

- Always run `-race` in CI; race conditions are silent killers.
- `t.Parallel()` on independent tests; capture loop vars (`tc := tc`) before — Go 1.22+ scopes per iteration but older codebases don't.
- `t.Cleanup(func() { ... })` over `defer` inside helpers — runs even if helper calls `t.FailNow`.
- Replace `time.Now` via DI or `clockwork.FakeClock`.

## Stack-specific gotchas

- **Loop variable capture pre-Go 1.22** — `for _, x := range xs { go func() { use(x) }() }` shares `x`. Check `go.mod` version.
- **`nil` interface vs `nil` concrete** — non-nil interface holding nil pointer is NOT `== nil`. Return `error` not `*MyError`.
- **Slice aliasing** — `s2 := s1[:0]` shares backing array; appending mutates `s1`. Use `slices.Clone`.
- **Map iteration order is randomized** — never depend on it; sort keys for deterministic output.
- **Goroutine leak via `http.Client` without timeout** — set `Timeout` or use `http.NewRequestWithContext`.
- **`defer` in a loop** — accumulates until function return. Refactor into a helper or call `Close` explicitly.
- **`encoding/json` ignores unexported fields silently** — capitalize or use `json:"name"` tags.
