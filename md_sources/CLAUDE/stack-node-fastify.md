# CLAUDE.md — Fastify addendum

<!--
  Merged into CLAUDE.md when STACK=node-fastify.
  Assumed stack: Fastify 4+ on Node 20+, TypeScript strict, Zod or TypeBox type provider.
-->

Supplements core CLAUDE.md with Fastify-specific best practices.

## Commands

```bash
npm install
npm run dev                # tsx watch src/server.ts (or fastify-cli start -w)
npm run build              # tsc -p tsconfig.json
npm start                  # node dist/server.js
npm run lint               # eslint --fix
npm run typecheck          # tsc --noEmit
npm test                   # vitest / tap / jest
npm run test:integration   # app.inject() in-process
```

## Idiomatic patterns (DO)

- **Type provider on the instance** — `@fastify/type-provider-zod` or `@fastify/type-provider-typebox`. Schemas double as runtime validation AND types: `fastify.withTypeProvider<ZodTypeProvider>()`.
- **Schemas on every route** — `{ schema: { body, querystring, params, response } }`. Faster (compiled validators + serializers) and safe for free.
- **Plugins for cross-cutting concerns** — auth, db, metrics, error mapping. Encapsulation is per-plugin; use `fastify-plugin` only to expose decorators to the parent scope.
- **Lifecycle hooks** — `onRequest` (auth, request ID), `preHandler` (authz, body shaping), `onSend` (response headers), `onResponse` (metrics). Pick the earliest fit.
- **`pino` is the default logger — use `request.log`** — every request gets a child logger with `reqId`. Don't import a separate logger.
- **Test via `app.inject()`** — in-process, no port binding, returns `LightMyRequest`. Faster and more deterministic than supertest.
- **Boot via factory function** — export `buildApp(opts)` returning `FastifyInstance`. Tests build their own; prod calls `buildApp().listen()`.
- **`@fastify/sensible`** — adds `httpErrors` (`reply.notFound()`, `reply.badRequest()`) and assertion helpers. Cleaner than raw status objects.
- **`@fastify/under-pressure`** — automatic 503 when event loop / memory thresholds exceeded.

## Anti-patterns (AVOID — call out and fix when seen)

- **Skipping schema validation** — `request.body` becomes `unknown` and unsafe. Fastify's validator is fast.
- **Global mutable state instead of plugins** — module-level `let cache = ...` breaks encapsulation, testability, multi-tenant isolation. Register a plugin and decorate.
- **Trusting `request.body` typing without a type provider** — body is `unknown` until validated. Configure the provider once; don't `as`-cast.
- **`process.exit()` instead of graceful shutdown** — drops in-flight requests. Use `fastify.close()` and exit only after it resolves.
- **Mixing async hooks with `done()` callbacks** — pick one per hook. `async` hook + `done()` double-resolves.
- **Registering plugins out of dependency order** — auth before its DB plugin → undefined decorator at runtime. `await fastify.register(...)` in order.
- **`reply.send()` AND returning a value** — pick one. Returning is idiomatic; `reply.send()` is for streams or when you must.
- **`fastify.decorate` after `listen()`** — decorators register during boot only. Adding later throws.
- **Returning `undefined` from a handler** — Fastify treats it as 200 with empty body. Be explicit: return an object or `reply.code(204).send()`.
- **Catching errors only to `reply.send(err)`** — bypasses the error handler and serializer. Throw or return rejected promise.
- **Blocking sync IO in handlers** — no `fs.readFileSync`, no `crypto.pbkdf2Sync` in hot paths. Fastify's perf depends on event-loop discipline.

## Test layer hierarchy

1. **Unit (services, schema-derived validators, pure helpers)** — no Fastify instance. Bulk of the suite.
2. **Integration (`app.inject()` against a built app)** — `const app = await buildApp({ logger: false }); await app.inject({ method: 'POST', url: '/users', payload })`. Fakes at DB/HTTP-client boundary.
3. **e2e with a listening server** — **LAST RESORT.** Only for real network behaviour (TLS, HTTP/2, upstream contracts).

## Tactical testing rules

- Pass `logger: false` (or silent logger) in tests; pino noise breaks deterministic output.
- Tear down with `await app.close()` in `afterEach`/`afterAll` to avoid handle leaks.
- Test schemas as units: feed invalid payloads to `app.inject()` and assert 400 + error shape.

## Stack-specific gotchas

- **Plugin encapsulation** — a decorator inside a plugin is NOT visible outside unless wrapped in `fastify-plugin`.
- **Schema response serialization is opt-in but strict** — fields not in the response schema are stripped. Audit after model changes.
- **`request.body` size limits** — `bodyLimit` defaults to 1MB. Configure per-route for uploads; don't crank globally.
- **CORS as a plugin (`@fastify/cors`)** — explicit origin allow-list. `*` with credentials is unsafe.
- **`fastify.ready()` vs `listen()`** — for tests use `await fastify.ready()` to load plugins without binding; `inject()` calls `ready` internally.
- **Error handler customization** — `fastify.setErrorHandler(...)` replaces the default. Make sure validation (400) and unknown (500) both have the right shape.
- **`request.id` is generated, not propagated** — to honour upstream IDs, configure `genReqId` to read `x-request-id` / `traceparent`.
- **Schema `$ref` resolution** — `fastify.addSchema({ $id: 'User', ... })` once and reference via `$ref: 'User#'`. Don't redefine per route.
- **`reply.hijack()` for streaming/SSE** — opts out of the default flow. Required for SSE; manage backpressure manually.
- **Multipart via `@fastify/multipart`** — disabled by default. Configure `limits` (size, count) explicitly; never trust client-reported sizes.
- **Plugin timeout (`pluginTimeout`)** — defaults to 10s; long-running boot work (migrations, warm caches) should run BEFORE `register` or be chunked.
- **`request.socket.remoteAddress` vs `request.ip`** — behind a proxy, set `trustProxy: true` so `request.ip` is the real client.
