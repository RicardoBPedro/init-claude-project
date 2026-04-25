# CLAUDE.md — Flutter addendum

<!--
  Merged into CLAUDE.md when STACK=flutter.
  Assumed stack: Flutter 3.x + Dart 3.x cross-platform mobile (iOS + Android), single state-management library per project.
-->

Supplements core CLAUDE.md with Flutter-specific best practices.

## Commands

```bash
flutter pub get                                  # install deps
flutter run -d <device-id>                       # run on device/sim
flutter build apk --release                      # Android release build
flutter build ipa --release                      # iOS release build
flutter test                                     # unit + widget tests
flutter test integration_test/                   # integration tests
flutter analyze                                  # static analysis (CI gate)
dart format --set-exit-if-changed .              # format check (CI gate)
dart run build_runner build --delete-conflicting-outputs  # codegen (freezed/riverpod)
```

## Idiomatic patterns (DO)

- **Pick ONE state management library per project** — Riverpod 2 (preferred for new code), Bloc, or Provider. Mixing fragments the mental model.
- **Riverpod 2 with code generation** — type-safe providers, compile-time DI graph, easy testing. `@riverpod Future<User> user(UserRef ref) => ...`
- **`const` constructors everywhere possible** — compile-time canonicalization eliminates rebuilds. Enable `prefer_const_constructors`.
- **Separate widget tree from logic** — `StatelessWidget` + a notifier/provider; `build()` reads state, doesn't compute it.
- **`freezed` for models + sealed classes for state** — immutable data classes, exhaustive `switch` on union types (`sealed class AuthState`).
- **Always `dispose()` controllers, streams, focus nodes** — `TickerProviderStateMixin`; pair every `init` with a `dispose`.
- **Commit `pubspec.lock` for apps** — reproducible builds; for packages, leave it out.
- **Use `ListView.builder` / `SliverList` for lists** — never map a long list to children eagerly.

## Anti-patterns (AVOID — call out and fix when seen)

- **`setState()` in deeply nested widgets** — cascading rebuilds. Lift state up or use a state mgmt lib.
- **Business logic inside `build()`** — extract to providers/notifiers; `build()` must be pure and cheap.
- **`BuildContext` used after `await`** — context may be unmounted. Use `if (!context.mounted) return;` after every async gap.
- **Rebuilding entire pages on small state changes** — split into smaller widgets; scope rebuilds with `Consumer` / `Selector`.
- **`StatefulWidget` when `StatelessWidget` + provider would do** — prefer the simpler primitive.
- **Package version drift** — commit `pubspec.lock` for apps; never unbounded `^` in production without review.
- **Global `MaterialApp` rebuilds on every theme tweak** — wrap theme in a provider, not in the root.
- **`Future.delayed` as a synchronization primitive** — race condition. Use `Completer`, streams, or `await` real signals.
- **Force-unwrap `!` outside boundaries you control** — replace with guard checks or null-coalescing; avoid `late` unless lifecycle is genuinely deferred.

## Test layer hierarchy

1. **Pure Dart unit tests** — no Flutter binding, no widgets. Test notifiers, repositories, mappers. Fast, default choice.
2. **Widget tests via `flutter_test`** — `pumpWidget` + `WidgetTester`, mock providers via `ProviderScope(overrides: ...)`. Use for rendering and interaction rules.
3. **Integration tests via `integration_test` on real device/emulator** — **LAST RESORT.** Reserve for end-to-end flows exercising platform channels, deep links, or genuine multi-screen navigation.

## Tactical testing rules

- Override providers in `ProviderScope` rather than mocking concrete classes; tests target behaviour, not wiring.
- `pumpAndSettle()` for finite animations; for streams use `pump(Duration)` with explicit timing — never bare `Future.delayed`.
- Golden tests are great for design-system widgets, brittle for full screens — scope tight.
- Inject `Clock` / random / IO at the notifier boundary; never `DateTime.now()` inside business logic.
- A widget test that needs `HttpOverrides` is a smell — mock the repository, not the network.

## Stack-specific gotchas

- iOS and Android diverge on keyboard, safe area, back-gesture — test both, not just the simulator you happen to have open.
- Hot reload preserves state; hot restart drops it. Repro bugs with restart, not reload.
- `Image.network` has no cache by default — use `cached_network_image` for production.
- Platform channels are async and lossy — assume failure, type the payload with `freezed`.
- `MediaQuery.of(context)` rebuilds on every metric change (keyboard, rotation) — use `MediaQuery.sizeOf(context)` (Flutter 3.10+) to scope rebuilds.

## Performance / Accessibility baseline

- `const` widgets + `RepaintBoundary` around expensive subtrees (charts, animations).
- Profile in `--profile` mode on a real device — debug numbers mislead.
- `ListView.builder` with `itemExtent` when item height is fixed — skips layout passes.
- `Semantics` widgets for non-visual navigation; ensure every interactive widget has a label.
- Respect platform text scaling (`MediaQuery.textScalerOf`); never hardcode font sizes.
- Verify minimum 4.5:1 contrast; test with TalkBack (Android) and VoiceOver (iOS) before shipping.
