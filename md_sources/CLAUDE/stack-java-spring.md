# CLAUDE.md — Java + Spring Boot addendum

<!--
  Merged into CLAUDE.md when STACK=java-spring.
  Assumed stack: Java 21 + Spring Boot 3.x + Gradle + JUnit 5 + Testcontainers.
-->

Supplements core CLAUDE.md with Java/Spring-specific best practices.

## Commands

```bash
./gradlew bootRun                                               # default profile
./gradlew bootRun --args='--spring.profiles.active=dev'         # dev profile
docker compose up -d                                            # local services (if compose present)
bash scripts/test-backend.sh                                    # full suite (handles docker context + wrapper)
bash scripts/test-backend.sh --tests "FQCN"                     # single class
./gradlew compileJava compileTestJava                           # sanity check (no Testcontainers)
./gradlew spotlessApply checkstyleMain                          # format + lint
./gradlew dependencyCheckAnalyze                                # OWASP scan (when configured)
```

Windows: `gradlew.bat` or `scripts/test-backend.sh` (auto-picks the wrapper).

## Idiomatic patterns (DO)

- **Records for DTOs / value objects** (Java 17+) — `public record UserDto(UUID id, String email) {}`.
- **`@Transactional(readOnly = true)` on queries** — method-level, not class-blanket. Hibernate skips dirty-checking.
- **`@RestControllerAdvice` for centralized error handling** — map domain exceptions to `ResponseEntity<ProblemDetail>` once.
- **JdbcClient (Spring 6.1+) or JPA Specifications over String JPQL** — typed, refactor-safe.
- **Virtual threads (Java 21+) where blocking I/O dominates** — `spring.threads.virtual.enabled=true`. Avoid for CPU-bound or `synchronized` holding locks across I/O.
- **Testcontainers for integration tests** — `@Container static PostgreSQLContainer<?>` matches prod image. No H2 dialect lies.

## Anti-patterns (AVOID — call out and fix when seen)

- **Field injection** (`@Autowired private UserService svc;`) — hides deps, breaks immutability. Use constructor injection.
- **`@Transactional` on the entire service class** — opaque scope, wraps non-DB methods. Annotate methods.
- **Catching `Exception` broadly without rethrow** — swallows `InterruptedException`. Catch specific or rethrow with `cause`.
- **Lazy-load in serialization layer** — `LazyInitializationException` on detached entity. Fix with fetch joins, `@EntityGraph`, or DTO projection — never `OpenSessionInView`.
- **Repository methods returning `Optional<List<T>>`** — empty list IS the absent state. Return `List<T>`.
- **Indiscriminate `@MockBean`** in `@SpringBootTest` — invalidates context cache. Use Mockito in unit tests; reserve `@MockBean` for slice tests.
- **`new RestTemplate()` ad-hoc** — inject `RestClient` (Spring 6.1+) or `WebClient` with timeouts and pooling.
- **`Date`, `Calendar`, `SimpleDateFormat`** — use `java.time` (`Instant`, `LocalDate`, `OffsetDateTime`).

## Test layer hierarchy

1. **Unit** — pure POJOs, no Spring, no DB. Fastest. Default.
2. **Slice** — `@WebMvcTest`, `@DataJpaTest`, `@JsonTest`, `@JdbcTest`. Loads only the relevant layer (~1s, no Docker).
3. **Full context** — `@SpringBootTest` + Testcontainers. **LAST RESORT.** Only when the rule needs the full container (security filter chain, `AFTER_COMMIT` listeners, cross-service flows, Flyway validation against real Postgres). Adds ~15-30s per class.

**Full-suite `./gradlew test` is double-digit minutes.** Run scoped: `bash scripts/test-backend.sh --tests "<FQCN>"`. Full-suite runs need user approval.

## Tactical testing rules

- Scheduler tests inject `Clock.fixed(...)` — never wall clock.
- Security assertions (401 / 403 / CORS) consolidate in a **single filter-chain contract test**.
- Reuse Testcontainers via `@Testcontainers(disabledWithoutDocker = true)` + static singleton; one start-up per JVM.

## Migration discipline (Flyway / Liquibase)

Entity changes require a matching migration in the same PR. `ddl-auto=update` on H2 masks missing migrations — validate against a clean DB before PR approval. **Smoke test:** drop dev DB, run app from scratch, confirm boot + one smoke path.

## Stack-specific gotchas

- Windows + Testcontainers hang → `DOCKER_CONTEXT=desktop-linux`.
- Killed Gradle run → zombie Ryuk + Postgres containers stall next `:test`.
- Scheduler tests flake → wall clock leaked in; inject `Clock`.
- Bean creation cycles → constructor injection surfaces them at startup; field injection masks until runtime.
- `@Async` + `@Transactional` on the same method → transaction does not propagate across thread boundary.
