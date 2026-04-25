# CLAUDE.md — Android / Kotlin addendum

<!--
  Merged into CLAUDE.md when STACK=android-kotlin.
  Assumed stack: Android with Kotlin 2.x, Jetpack Compose dominant for new UI, AndroidX Views allowed only on legacy surfaces.
-->

Supplements core CLAUDE.md with Android / Kotlin-specific best practices.

## Commands

```bash
./gradlew assembleDebug                          # debug APK
./gradlew installDebug                           # install on connected device/emulator
./gradlew test                                   # JVM unit tests (all variants)
./gradlew testDebugUnitTest                      # JVM unit tests (debug variant)
./gradlew connectedDebugAndroidTest              # instrumented tests on device/emulator
./gradlew lint                                   # Android lint
./gradlew ktlintCheck detekt                     # Kotlin lint + static analysis
./gradlew assembleRelease                        # release build with R8
./gradlew :app:generateBaselineProfile           # baseline profile for startup
```

## Idiomatic patterns (DO)

- **Jetpack Compose for all new UI** — Views only when extending legacy or wrapping a third-party widget without a Compose equivalent.
- **ViewModel + state hoisting** — UI state in `StateFlow` (or Compose `State`); composables receive state and emit events upward.
- **`@Immutable` and `@Stable` annotations** — let the Compose compiler skip recomposition when inputs are unchanged.
- **Coroutines + `Flow` over LiveData** — LiveData only at View-system boundaries; new code is `StateFlow` / `SharedFlow`.
- **Hilt for dependency injection** — `@HiltViewModel`, scoped components; avoid hand-rolled service locators.
- **Room over raw SQLite / SharedPreferences for structured data** — type-safe queries, migrations, coroutine + Flow support.
- **Lifecycle-aware coroutines** — `viewModelScope`, `lifecycleScope`, `repeatOnLifecycle(STARTED)` for collecting flows in UI.
- **Baseline profiles for cold-start critical paths** — measurable startup wins on real devices.
- **Compose testing API for UI** — `createComposeRule()`, `onNodeWithTag` over Espresso for new screens.

## Anti-patterns (AVOID — call out and fix when seen)

- **State in composables across config changes** — use `ViewModel` + `SavedStateHandle`. `remember { }` survives recomposition, not process death.
- **Blocking the main thread** — `runBlocking` in production is a bug. Use `withContext(Dispatchers.IO)` or proper coroutine scopes.
- **Leaking `Context` (especially `Activity`) into `ViewModel`** — store only `Application` if you must; otherwise inject what you actually need.
- **`GlobalScope.launch`** — unsupervised, leak-prone. Use `viewModelScope` / `lifecycleScope` / a scoped `CoroutineScope`.
- **Mutable shared state across composables without snapshots** — wrap in `mutableStateOf` / `mutableStateListOf`; ordinary `var` won't recompose.
- **Ignoring R8 / ProGuard rules for libraries** — release builds will crash at runtime; test the release variant in CI.
- **`findViewById` chains in new code** — use Compose, or View Binding for legacy.
- **Hardcoded strings, colors, dimens** — `strings.xml` for i18n + a11y; `colors.xml` / theme tokens for theming.
- **`!!` (force-unwrap) on nullable types** — guard with `?.let`, `requireNotNull`, or model the type so it can't be null.
- **One mega-`ViewModel` per screen** — split by feature/UI section; recombine state in the composable.

## Test layer hierarchy

1. **JUnit unit tests on ViewModels, repositories, mappers, use cases** — JVM-only, `kotlinx-coroutines-test` with `runTest` and `TestDispatcher`. Default choice.
2. **Compose UI tests with `createComposeRule()`** — runs on JVM (Robolectric) or device; assert on semantics, not pixels. Use for screen-level interaction rules.
3. **Instrumented Android tests on device/emulator** — **LAST RESORT.** Reserve for true integration: navigation graph, deep links, system services, real Room migrations.

## Tactical testing rules

- Inject a `TestDispatcher` (`StandardTestDispatcher` for ordering, `UnconfinedTestDispatcher` for eager) — never `Dispatchers.Main` directly.
- Use Turbine for `Flow` assertions — `flow.test { assertThat(awaitItem()).isEqualTo(...) }`.
- Compose tests query by `testTag` or semantics, not displayed text (i18n breaks otherwise).
- Fakes > mocks for repositories — a small in-memory implementation reads better than 20 `every { } returns`.
- Room migration tests run on instrumented test runner — worth the cost; ship them.

## Stack-specific gotchas

- Configuration changes (rotation, dark mode, locale) recreate the Activity by default — `ViewModel` survives, `remember { }` does not.
- `collectAsState()` ignores lifecycle; prefer `collectAsStateWithLifecycle()` to avoid wasted work in the background.
- Compose `key()` matters for list identity; wrong keys cause animation glitches and lost state.
- Background work limits tighten every Android version — use `WorkManager`, not raw `Service`s, for deferrable work.
- App Bundle signing differs from APK signing; `bundletool` is required to reproduce what users actually install.
- StrictMode in debug catches main-thread IO and leaked closables — keep it on.

## Performance / Accessibility baseline

- Stable keys + `@Immutable` data classes to keep recomposition skipping; verify with the Compose Compiler metrics report.
- Profile with Layout Inspector (recomposition counts) and Macrobenchmark (startup, scroll jank) — not by eye.
- Baseline profiles for the critical startup path; R8 minification + resource shrinking on release builds.
- `contentDescription` on every `Image` / `Icon` that conveys meaning; `null` only for purely decorative.
- Use `Modifier.semantics { }` to merge or override; test with TalkBack on a real device.
- Support dynamic font scaling (`sp` units, never `dp` for text) and `fontScale` up to 200%.
- Contrast minimum 4.5:1 (3:1 for large text); honour `Configuration.fontScale` and reduce-motion settings.
