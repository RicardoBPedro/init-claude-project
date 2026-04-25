# CLAUDE.md — .NET / ASP.NET Core addendum

<!--
  Merged into CLAUDE.md when STACK=dotnet-aspnet.
  Assumed stack: ASP.NET Core 8+ (Minimal APIs OR controllers), EF Core 8+, xUnit, FluentAssertions, Testcontainers, NRT on.
-->

Supplements core CLAUDE.md with ASP.NET Core-specific best practices.

## Commands

```bash
dotnet new webapi -n MyApi --use-minimal-apis  # scaffold
dotnet run --project src/MyApi                 # dev server
dotnet watch --project src/MyApi run           # hot reload
dotnet test                                    # all tests
dotnet test --filter "FullyQualifiedName~UserServiceTests"
dotnet format                                  # lint + format
dotnet build -c Release                        # build
dotnet ef migrations add InitialCreate         # EF migration
dotnet ef database update                      # apply migrations
dotnet user-secrets set "Key" "Value"          # local secrets
dotnet pack -c Release                         # NuGet package
```

## Idiomatic patterns (DO)

- **Pick one API style per service** — minimal APIs for small services; controllers for larger surfaces with filters, model binding, conventions. Don't mix.
- **`IOptions<T>` for config binding** — `builder.Services.Configure<MyOptions>(builder.Configuration.GetSection("My"));`. Validate with `.ValidateDataAnnotations().ValidateOnStart()`.
- **`ILogger<T>` with structured logging** — `_logger.LogInformation("User {UserId} created order {OrderId}", userId, orderId);`. Never `string.Format` into the template.
- **`IResult` / `Results.X` returns in minimal APIs** — `Results.Ok(dto)`, `Results.NotFound()`, `Results.Problem(...)`. Typed via `Results<Ok<UserDto>, NotFound>` for OpenAPI.
- **`record` for DTOs** — immutable, value-equality. `public record UserDto(Guid Id, string Email);`
- **EF Core: `AsNoTracking()` for reads** — bypasses change tracker; measurable perf win on hot endpoints.
- **`AddProblemDetails()` middleware** — RFC 7807 responses; consistent shape. Combine with global exception handler.
- **xUnit + FluentAssertions + Testcontainers** — `result.Should().BeOfType<Ok<UserDto>>();`; real Postgres/Redis via Testcontainers for integration.

## Anti-patterns (AVOID — call out and fix when seen)

- **`static` business logic** — hard to mock, hidden dependencies. Inject via interfaces (`IClock`, `IEmailSender`).
- **`async void`** — exceptions crash the process; not awaitable. Only legal for event handlers. Use `async Task`.
- **`.Result` / `.Wait()` / `.GetAwaiter().GetResult()`** — sync-over-async deadlocks under ASP.NET sync context and starves the threadpool. Make the chain async.
- **Injecting `IServiceProvider` to resolve at runtime** — service locator anti-pattern. Inject the concrete service or a factory delegate (`Func<IFoo>`).
- **EF Core entities leaking to the API surface** — over-posting, lazy-load mid-serialization, schema coupling. Map to DTOs (Mapster, AutoMapper, manual records).
- **Ignoring nullable warnings** — `string foo = null!;` and `#nullable disable` defeat NRT. Fix the root cause.
- **Not awaiting tasks** — compiler warns `CS4014`. `await` it, capture (`_ = task;`) intentionally, or use `BackgroundService`/queue.
- **`DbContext` lifetime > scoped** — singleton/static is a thread-safety landmine. Stay scoped; use `IDbContextFactory<T>` for parallel work.
- **Catch-all `catch (Exception)` swallowing** — masks bugs. Catch specific types and let the rest bubble to the global handler.
- **Manual `JsonSerializer.Serialize` inside endpoints** — bypasses content negotiation, options, OpenAPI. Return objects.

## Test layer hierarchy

1. **Unit (xUnit + Moq or NSubstitute)** — pure logic, services in isolation, mocks at boundaries. No web host, no DB. Hundreds of tests, sub-second total.
2. **Integration via `WebApplicationFactory<TProgram>` + Testcontainers** — real pipeline, real DI, real Postgres/Redis in Docker. Asserts wiring + SQL + middleware. `using var factory = new WebApplicationFactory<Program>();`
3. **End-to-end (separate suite, LAST RESORT)** — Playwright or BDD against a deployed environment. Run on a schedule, not per-PR. Reserve for cross-service flows.

## Tactical testing rules

- `WebApplicationFactory<Program>` requires `public partial class Program { }` at the bottom of `Program.cs` (top-level statements need this).
- Override services via `builder.ConfigureTestServices(services => services.AddSingleton<IClock, FakeClock>());`. Don't reach into `IServiceProvider`.
- Testcontainers per-collection (xUnit `ICollectionFixture<T>`) so the container starts once per run.
- `IClock` / `TimeProvider` (.NET 8) — never call `DateTime.UtcNow` directly in business code.
- FluentAssertions: `.Should().BeEquivalentTo(...)` for object graphs; `.Should().Be(...)` for scalars.
- HTTP outbound: `IHttpClientFactory` + typed client; mock with `MockHttp` or a delegating handler.

## Stack-specific gotchas

- **EF Core change tracker memory** — long-lived `DbContext` accumulates tracked entities. Scoped + `AsNoTracking()` for reads.
- **`ConfigureAwait(false)` in app code** — unnecessary in ASP.NET Core (no sync context); still required in libraries that may run under one.
- **Minimal API parameter binding order** — route → query → header → body. Ambiguous types fail at startup; annotate with `[FromBody]`/`[FromQuery]`.
- **`IOptionsSnapshot<T>` vs `IOptions<T>`** — snapshot reloads per request (scoped); plain `IOptions<T>` is singleton. Don't inject snapshot into singletons.
- **Migrations on startup** — convenient in dev, dangerous in prod (race across replicas). Run as separate deploy step or with leader election.
- **`HttpClient` lifetime** — never `new HttpClient()` per call (socket exhaustion). Use `IHttpClientFactory` with named/typed clients.
- **`record` equality + EF Core** — value-equality conflicts with EF identity tracking. Use `record` for DTOs only, classes for entities.
- **Trimming / AOT** — reflection-based libs (some serializers, AutoMapper) break under PublishTrimmed/AOT. Verify before enabling.
- **CORS, AuthN, AuthZ middleware order** — `UseRouting` → `UseCors` → `UseAuthentication` → `UseAuthorization` → endpoints. Reordering silently breaks security.
