# CLAUDE.md — NestJS addendum

<!--
  Merged into CLAUDE.md when STACK=node-nest.
  Assumed stack: NestJS 10+ on Node 20+, TypeScript strict, class-validator DTOs.
-->

Supplements core CLAUDE.md with NestJS-specific best practices.

## Commands

```bash
npm install
npm run start:dev          # watch mode (ts-node + chokidar)
npm run start:debug        # with --inspect
npm run build              # nest build (tsc + asset copy)
npm run start:prod         # node dist/main
npm run lint               # eslint --fix
npm run test               # jest unit
npm run test:watch
npm run test:cov
npm run test:e2e           # jest --config test/jest-e2e.json (supertest)
npx tsc --noEmit           # typecheck without build
```

## Idiomatic patterns (DO)

- **DTOs + global `ValidationPipe`** — `app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }))`. DTOs are classes with `class-validator` decorators.
- **Interceptors for cross-cutting concerns** — logging, metrics, response shaping, caching. Bind via `APP_INTERCEPTOR` provider for testability.
- **Guards for authn/authz** — `CanActivate` + `@SetMetadata('roles', [...])` + `Reflector` for RBAC. Not in services.
- **`Test.createTestingModule` for unit/integration** — override providers via `.overrideProvider(X).useValue(mockX)`.
- **e2e via supertest + real Nest app** — `await app.init()` then `request(app.getHttpServer()).post('/users')`.
- **`useFactory` for config-driven providers** — prefer over `forwardRef`. Async factories for DB clients, secrets, feature flags.
- **Exception filters for error mapping** — `ExceptionFilter` translates domain errors to HTTP. Bind via `APP_FILTER`.
- **`@nestjs/swagger` decorators next to DTOs** — `@ApiProperty()`. One source of truth.

## Anti-patterns (AVOID — call out and fix when seen)

- **`forwardRef` to escape circular deps** — design smell. Extract a third module/interface or a `*-shared` module.
- **`any` in DI typing** — defeats reflection. Use `unknown` and narrow, or interface + token (`@Inject(USER_REPO)`).
- **Mutable shared state in providers** — default scope is `SINGLETON`; per-request state leaks across tenants. Use `Scope.REQUEST` or pass context explicitly.
- **Inline DTOs without validators** — `@Body() body: { email: string }` skips validation. Always use a class with `class-validator`.
- **Testing controllers via real HTTP only** — too slow as primary loop. Unit-test the service first; reserve HTTP for routing, guards, pipes.
- **Throwing raw `Error` from services** — use `HttpException` subclasses (`NotFoundException`, `BadRequestException`) or a custom filter. Raw errors leak as 500.
- **Logging via `console.log`** — use injected `Logger` (`new Logger(UsersService.name)`) so context shows and tests can silence.
- **Returning entities directly from controllers** — leaks DB columns. Map to DTO via `class-transformer` `@Expose()`/`@Exclude()` or explicit mapper.
- **Cron via `setInterval`** — use `@nestjs/schedule` with `@Cron()` for DI, lifecycle, testing.

## Test layer hierarchy

1. **Unit (services, pure functions)** — instantiate the service directly with hand-rolled fakes. No `Test.createTestingModule`. Default.
2. **Integration (TestingModule with real providers)** — `Test.createTestingModule` with the real module, override only IO boundaries. Validates wiring, guards, pipes, interceptors.
3. **e2e (supertest against `app.getHttpServer()`)** — **LAST RESORT.** Reserve for security chains (auth → guard → controller → service), `AFTER_COMMIT` listeners, cross-module flows.

## Tactical testing rules

- Mock at module boundaries (repos, HTTP clients, queues), never internal collaborators.
- Test guards as units with a fake `ExecutionContext` — don't spin up the app.

## Stack-specific gotchas

- **Decorators require `emitDecoratorMetadata` + `experimentalDecorators`** — missing metadata silently breaks DI.
- **Circular module imports** — manifest as `Cannot read properties of undefined` at boot. Check the graph before reaching for `forwardRef`.
- **Global pipes/guards/interceptors via `app.useGlobalX`** — NOT injectable. Use `APP_PIPE` / `APP_GUARD` / `APP_INTERCEPTOR` providers instead.
- **Request-scoped providers cascade** — one `Scope.REQUEST` makes every consumer request-scoped. Audit before introducing.
- **Microservices vs HTTP transports** — `@MessagePattern` and `@EventPattern` only fire on the matching transport; need explicit `app.connectMicroservice()`.
- **`@nestjs/config` `get()` returns `T | undefined`** — assert presence at boot via validation schema; never `!` in business code.
- **TypeORM/Mongoose injection tokens** — use `@InjectRepository(User)` / `@InjectModel(User.name)`; direct repo import skips test-override.
- **`enableShutdownHooks()`** — call it so `OnModuleDestroy` / `OnApplicationShutdown` fire on SIGTERM. Without it, queues and DB pools leak.
- **`@nestjs/bull` / `@nestjs/bullmq` for queues** — DI-aware processors. Don't instantiate BullMQ workers manually outside the module graph.
- **Versioning** — `app.enableVersioning({ type: VersioningType.URI })` for `/v1/`, `/v2/`. Plan before the first breaking change.
- **Health checks via `@nestjs/terminus`** — DB/HTTP/disk/memory indicators on `/health`. Roll-your-own miss real outages.
