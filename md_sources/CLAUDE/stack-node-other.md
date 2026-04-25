# CLAUDE.md — Node (other frameworks) addendum

<!--
  Merged into CLAUDE.md when STACK=node-other.
  Assumed stack: Node 20+ with Koa, Hono, Elysia, tRPC server, raw http, or another non-Nest/Express/Fastify framework. TypeScript strict.
-->

Supplements core CLAUDE.md with patterns common to Node backends that aren't Nest/Express/Fastify.

## Commands

```bash
npm install
npm run dev                # tsx watch / bun --watch / framework-specific dev
npm run build              # tsc -p tsconfig.json (or framework bundler)
npm start                  # node dist/index.js
npm run lint               # eslint --fix
npm run typecheck          # tsc --noEmit
npm test                   # vitest / node --test / framework runner
npm run test:integration
```

## Idiomatic patterns (DO)

- **Explicit error types** — `Result<T, E>` (e.g. `neverthrow`) or discriminated unions. Throwing across module boundaries hides failure modes.
- **Runtime validation at every entry point** — `zod` (or `valibot`) for HTTP body/query/headers, queue payloads, external API responses. Process-boundary data is `unknown` until parsed.
- **Validate env at startup** — `EnvSchema.parse(process.env)` once at boot; export the typed result. Fail fast on missing.
- **Graceful shutdown on SIGTERM/SIGINT** — stop accepting connections, drain in-flight, close DB pools, exit. Rolling deploys depend on it.
- **HTTP/JSON via the framework, not raw streams** — Hono `c.json()`, Koa `ctx.body`, tRPC procedure return. Reaching for `res.write` is almost always wrong.
- **Async cancellation via `AbortSignal`** — pass the request signal to fetch and long-running ops so client disconnects don't leak work.
- **Health and readiness endpoints** — `/healthz` (process alive) and `/readyz` (deps reachable).
- **Dependency injection via factory functions** — `buildUserService({ db, clock, logger })`. No framework needed; trivially testable.

## Anti-patterns (AVOID — call out and fix when seen)

- **Untyped `any` from JSON parsing** — `JSON.parse()` returns `any`. Validate with `zod` and use the inferred type. Don't `as MyType`.
- **Uncaught promise rejections** — every promise must be `await`ed (with try/catch) or have `.catch()`. Set `process.on('unhandledRejection', ...)` to log and crash, not swallow.
- **Blocking the event loop with sync work** — `crypto.pbkdf2Sync`, big `JSON.parse`, sync compression. Use async, `worker_threads`, or a queue.
- **Mixing CommonJS and ESM in the same package** — pick one (`"type": "module"` is modern default). Mixed produces dual-package hazards.
- **Leaking stack traces to clients in prod** — error responses are `{ error: 'INTERNAL', requestId }`. Stack to logs only.
- **Global singletons created at import time** — DB pools, HTTP clients. Painful for tests. Wrap in a factory and inject.
- **Catching `Error` to log-and-ignore** — recover with documented fallback or rethrow. Silent catches hide bugs for months.
- **`process.env.X` scattered through the codebase** — read env once at boot through a validated schema; pass typed config.
- **Mutating shared request context across async boundaries without `AsyncLocalStorage`** — request-scoped data needs `AsyncLocalStorage` (or framework equivalent) or explicit passing.
- **Long-running tasks inside the request lifecycle** — anything > a few seconds belongs in a queue (BullMQ, SQS, Cloud Tasks).

## Test layer hierarchy

1. **Unit (pure logic, validators, services with fake IO)** — no framework, no network. Bulk of the suite; runs in ms.
2. **Integration (framework-bound code with fakes at IO boundaries)** — Hono `app.request(...)`, Koa via supertest, tRPC via `createCaller`. Validates routing, middleware, validation.
3. **e2e against a real running server** — **LAST RESORT.** Reserve for business-critical flows (payments, auth chains, contract tests).

## Tactical testing rules

- Build the app via factory `buildApp(deps)` so tests inject fakes; prod composes real deps.
- Fakes at IO boundaries only. No mocking of internal collaborators.

## Stack-specific gotchas

- **Top-level `await` requires ESM** — `"type": "module"` and `"module": "ESNext"` (or `NodeNext`). CJS won't parse it.
- **Hono / Elysia run on Bun, Node, Deno, edge** — `node:` builtins (`fs`, `crypto`) won't run on edge. Pick a runtime target.
- **tRPC server context** — set per-request via `createContext`, accessed in procedures. Don't smuggle data via globals.
- **Koa `ctx.body = stream`** — Koa pipes streams natively; setting `ctx.body` AND `ctx.res.write` corrupts output.
- **Raw `http.createServer`** — you own routing, parsing, errors, timeouts. Almost always reach for a framework.
- **`AbortController` and fetch** — Node 20+ has global `fetch`; pass `signal` so timeouts and disconnects propagate.
- **Worker threads share no memory by default** — pass via `postMessage` (structured clone). Use `SharedArrayBuffer` deliberately.
- **Container readiness vs liveness** — readiness fails during startup and graceful shutdown so traffic drains; liveness only on truly dead processes.
- **`fetch` keep-alive** — Node's global `fetch` does NOT keep connections alive by default. For high throughput, configure an undici `Agent` with `keepAliveTimeout` and reuse.
- **Time zones** — never store or compare local-string times. UTC ISO-8601 in storage; format at the edge.
- **`AsyncLocalStorage` overhead** — cheap but not free; don't put it in every leaf. Set context once per request at the framework hook layer.
- **Native modules and lockfiles** — `npm ci` (not `npm install`) in CI. `bcrypt`, `argon2`, `better-sqlite3` need matching Node/OS; pin in Docker.
- **`structuredClone` for deep copies** — built-in since Node 17. Don't reach for `JSON.parse(JSON.stringify(x))` — drops `Date`, `Map`, `undefined`.
