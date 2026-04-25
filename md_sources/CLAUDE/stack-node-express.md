# CLAUDE.md — Express addendum

<!--
  Merged into CLAUDE.md when STACK=node-express.
  Assumed stack: Express 4.x or 5.x on Node 20+, TypeScript strict, zod for validation.
-->

Supplements core CLAUDE.md with Express-specific best practices.

## Commands

```bash
npm install
npm run dev                # tsx watch src/index.ts (or nodemon + ts-node)
npm run build              # tsc -p tsconfig.json
npm start                  # node dist/index.js
npm run lint               # eslint --fix
npm run typecheck          # tsc --noEmit
npm test                   # vitest / jest
npm run test:watch
npm run test:integration   # supertest against the app instance
```

## Idiomatic patterns (DO)

- **`zod` (or `yup`) for body/query/params** — `const body = UserSchema.parse(req.body)`. Fail with 400 + structured error.
- **Error handler LAST, with 4 args** — `app.use((err, req, res, next) => {...})`. 3-arg handlers won't catch errors. Register after routes and 404.
- **`helmet`, `cors` (allow-list), rate limiter in prod** — `helmet()`, `cors({ origin: ALLOWED })`, `express-rate-limit`. Defaults are unsafe.
- **404 handler before the error handler** — `app.use((req, res) => res.status(404).json({...}))` so unmatched routes don't leak HTML.
- **Async errors via wrapper or `express-async-errors`** — `const asyncH = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next)`. Rejections must reach the error handler.
- **Integration tests via supertest** — `request(app).post('/users')` against the exported `app` (don't `listen()` in tests).
- **Module augmentation for typed `req.user`** — `declare global { namespace Express { interface Request { user?: AuthUser } } }` once.

## Anti-patterns (AVOID — call out and fix when seen)

- **Callback-style async handlers without try/catch** — Express 4 swallows rejections. Wrap or upgrade to Express 5 (which forwards rejections).
- **Business logic in route handlers** — handlers should be ~10 lines: parse, call service, respond.
- **`app.use(cors())` with default `*` in prod** — explicit allow-list. Wildcard with credentials is a CSRF/credential-leak vector.
- **`express.json()` without size limit** — `express.json({ limit: '100kb' })`. Cap on large endpoints.
- **Mutating `req` to pass data between middleware** — `req.user` is fine if typed via augmentation; ad-hoc untyped `req.foo` is a footgun. Prefer `res.locals` or typed `AsyncLocalStorage`.
- **Storing state on the `app` object** — `app.locals` is global. Pass deps explicitly (factory functions returning a router).
- **Catching errors only to log and continue** — rethrow to the error handler so response/status stays consistent.
- **Returning inside middleware without calling `next()`** — except explicit short-circuits (auth fail, 404). Forgotten `next()` hangs the request.
- **`req.params`/`req.query` typed as `string`** — they're `ParsedQs` and may be arrays. Validate with zod and use parsed type.

## Test layer hierarchy

1. **Unit (services, validators, pure modules)** — no Express, no IO. Fakes for repos. Bulk of the suite.
2. **Integration (supertest + real app, fakes at IO boundary)** — `request(app)` with in-memory or test DB. Validates routing, middleware order, validation, error handler.
3. **e2e against a real running server** — **LAST RESORT.** Reserve for cross-process flows (auth → backend → external webhook) or contract tests.

## Tactical testing rules

- Export `app` separately from `listen()` so supertest drives it without binding a port.
- Test the error handler explicitly: a route that throws → expected status + body shape.
- Test middleware in isolation with fake `req`/`res`/`next`; integration covers ordering.

## Stack-specific gotchas

- **Express 4 vs 5 promise handling** — Express 4 does NOT forward rejected promises; Express 5 does. Confirm version before trusting bare `async` handlers.
- **Middleware order matters** — body parser before validators, auth before authz, error handler last. Misordering silently 401s or 500s.
- **`req.body` is `any` by default** — augment via `Request<Params, ResBody, ReqBody>` generics or zod-inferred type.
- **`trust proxy` for IPs and HTTPS** — behind LB/CDN, set `app.set('trust proxy', 1)` so `req.ip` and `req.secure` reflect the client.
- **Streaming responses** — don't `res.json()` after `res.write()`; pick one. For large payloads use `pipeline()` from `node:stream/promises`.
- **Graceful shutdown** — close HTTP server on SIGTERM/SIGINT, drain in-flight, then exit. Otherwise rolling deploys cut connections.
- **`res.send()` vs `res.json()`** — `res.json()` always serializes and sets `application/json`. `res.send()` guesses by argument type. Be explicit.
- **Sessions / cookies** — `cookie-session` and `express-session` differ in store and threat model. Pick deliberately; set `httpOnly`, `secure`, `sameSite`.
- **Multipart uploads** — `multer` or `busboy`; never accept arbitrary file types/sizes. Validate MIME and bytes on disk after upload.
- **Router order over regex** — Express matches in registration order. Reordering silently changes routing.
- **Request timeouts** — neither Node nor Express enforce one. Set `server.setTimeout(30_000)` (or per-route) to bound runaway handlers.
