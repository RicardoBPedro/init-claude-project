# CLAUDE.md — Rust addendum

<!--
  Merged into CLAUDE.md when STACK=rust.
  Assumed stack: Rust 1.75+ stable, cargo workspaces, tokio for async, thiserror/anyhow.
-->

Supplements core CLAUDE.md with Rust-specific best practices.

## Commands

```bash
cargo build --workspace --all-targets                           # build everything
cargo test --workspace --all-targets                            # full suite (unit + integration + doc tests)
cargo test -p <crate> <test_name>                               # scoped run
cargo clippy --workspace --all-targets -- -D warnings           # lint, deny on warnings
cargo fmt --all -- --check                                      # CI-style format check
cargo fmt --all                                                 # apply formatting
cargo doc --workspace --no-deps --open                          # generate + view docs
cargo machete                                                   # find unused dependencies
cargo audit                                                     # known CVE scan
cargo run -p <bin>                                              # run a binary in a workspace
```

## Idiomatic patterns (DO)

- **Library errors with `thiserror`** — `#[derive(Error, Debug)] enum FooError { #[error("io: {0}")] Io(#[from] std::io::Error) }`. Typed, composable, zero-alloc variants.
- **Binary errors with `anyhow`** — `anyhow::Result<()>` at `main`/CLI boundaries; downcast when needed. Don't expose from library APIs.
- **Ownership-first design** — model with `&T`, `&mut T`, owned `T`. `Rc<RefCell<T>>` / `Arc<Mutex<T>>` only when shared mutation is essential.
- **Async with `tokio` and structured concurrency** — `tokio::select!`, `JoinSet`, `tokio::spawn` with explicit `CancellationToken`.
- **Doc comments with runnable examples** — `/// # Examples\n/// ```\n/// assert_eq!(add(2,2), 4);\n/// ````. Compiled by `cargo test`.
- **Const generics over runtime size args** — `fn buffer<const N: usize>() -> [u8; N]` beats heap-allocated `Vec` when size is known.
- **Newtype wrappers over primitives** — `struct UserId(Uuid);` prevents passing `OrderId` where `UserId` is expected.

## Anti-patterns (AVOID — call out and fix when seen)

- **`unwrap()` / `expect()` outside tests, examples, or proven invariants** — return `Result`. If panic is correct, `expect` with the invariant.
- **`.clone()` to escape the borrow checker** — refactor lifetimes, use `&`, or restructure ownership. Cloning `String`/`Vec` in hot loops costs.
- **`Arc<Mutex<T>>` everywhere** — first ask if the data needs sharing. Often a channel (`mpsc`) or message-passing is cleaner.
- **`Box<dyn Trait>` when generics work** — generics monomorphize and inline; use `dyn` for heterogeneous collections or to break compile-time fan-out.
- **`unsafe` without a `// SAFETY:` comment + minimal scope** — every `unsafe` block must justify caller invariants.
- **`.await` inside loops on independent futures** — serializes I/O. Use `futures::future::join_all`, `try_join_all`, or `JoinSet` for fan-out.
- **`std::sync::Mutex` across `.await`** — blocks the executor thread. Use `tokio::sync::Mutex` or drop the guard before awaiting.
- **Blocking I/O on a tokio runtime thread** — wrap in `tokio::task::spawn_blocking`.
- **`String` parameters everywhere** — accept `&str` or `impl AsRef<str>`; only take `String` when ownership transfer is real.
- **Catch-all `match _ =>` in error handling** — exhaustive matching surfaces new variants at compile time. Prefer named arms.
- **Re-exporting third-party types in public API without a wrapper** — leaks the dependency into your SemVer surface.

## Test layer hierarchy

1. **Unit tests in `#[cfg(test)] mod tests`** at the bottom of each module — access to private items, fastest feedback. Default for pure logic.
2. **Integration tests in `tests/<name>.rs`** — black-box, public API only. For cross-module behaviour and crate-level contracts.
3. **End-to-end / system tests** — separate binary or `tests/e2e/`, `testcontainers` for DBs, real HTTP servers. **LAST RESORT.** Reserve for emergent behaviour.

Doc tests (`/// ```rust ... ````) double as documentation and regression tests.

## Tactical testing rules

- `#[tokio::test]` (or `#[tokio::test(flavor = "multi_thread")]`) for async; never `block_on` ad-hoc.
- Inject time via `tokio::time::pause()` + `advance()` or a `Clock` trait — never `tokio::time::sleep` in tests.
- `proptest` / `quickcheck` for property-based coverage of pure functions; great for parsers, codecs, math.
- Snapshot tests with `insta` for stable structured output (JSON, AST, error messages); review diffs in PR.

## Stack-specific gotchas

- **`async fn` in traits stabilized in 1.75** — older crates use `async-trait` (boxed futures); mixing causes friction.
- **`Send` / `Sync` bound surprises** — `Rc<T>` is not `Send`; using inside `tokio::spawn` fails. Use `Arc<T>`.
- **Lifetime elision in returns** — `fn foo(s: &str) -> &str` is fine; multiple input lifetimes need explicit annotations.
- **`From` vs `Into`** — implement `From`; `Into` comes free. Don't implement both.
- **`Default` derive on generics** — requires `T: Default` on every field; manual impl is sometimes clearer.
- **`#[derive(Copy)]` on large structs** — copies on every move; prefer `Clone` and explicit `.clone()`.
- **`tokio::spawn` requires `'static`** — captured references must be owned (`Arc`, `String`) or `move`d.
- **Trait object safety** — `dyn Trait` requires no generic methods, no `Self` in return position; design with this in mind if `dyn` is on the table.
- **`cargo test` runs in parallel by default** — shared state (env vars, files, ports) needs synchronization or `--test-threads=1`.
