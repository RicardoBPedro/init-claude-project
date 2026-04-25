# CLAUDE.md — Swift / iOS addendum

<!--
  Merged into CLAUDE.md when STACK=swift-mobile.
  Assumed stack: Swift 5.9+, iOS 16+ deployment target, SwiftUI dominant for new screens, UIKit retained only for legacy surfaces.
-->

Supplements core CLAUDE.md with Swift / iOS-specific best practices.

## Commands

```bash
xcodebuild -scheme App -destination 'generic/platform=iOS' build      # device build
xcodebuild -scheme App -destination 'platform=iOS Simulator,name=iPhone 15' build  # sim build
xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=iPhone 15'   # unit + UI tests
xcodebuild -scheme App -only-testing:AppTests test                    # unit only
xcodebuild -scheme App -only-testing:AppUITests test                  # UI tests only
swift package resolve                                                  # SPM deps
swiftlint --strict                                                     # lint (CI gate)
swift-format format -i -r Sources/                                     # format in place
```

## Idiomatic patterns (DO)

- **SwiftUI for every new screen** — UIKit only when bridging legacy or when SwiftUI lacks a primitive.
- **`@Observable` macro on iOS 17+** — replaces `ObservableObject` + `@Published`; finer tracking, less boilerplate. `@Observable final class UserVM { ... }`
- **Structured concurrency (`async`/`await` + `Task`) over GCD** — cancellation propagates through the task tree for free.
- **`Sendable` conformance for cross-actor types** — data races become a compile error, not a Sentry ticket.
- **Explicit `@MainActor` on UI types** — view models that drive views, not scattered `DispatchQueue.main.async`.
- **Protocol-oriented design + protocol witnesses for testing** — inject `any UserService` (or a struct of closures) instead of subclassing.
- **XCTest today, Swift Testing (Swift 6) for new suites** — `@Test` macros, parameterized tests, expressive `#expect`.
- **SwiftUI `.task` modifier for async work tied to view lifetime** — auto-cancels on disappear; avoid `Task { }` inside `body`.

## Anti-patterns (AVOID — call out and fix when seen)

- **Force-unwraps (`!`) outside IBOutlets** — replace with `guard let`, `if let`, or `??`. Crash-on-nil is not error handling.
- **Singletons (`.shared`) carrying mutable state** — pass dependencies through initializers; testability and Swift 6 concurrency suffer.
- **`DispatchQueue.main.async` inside `async` contexts** — use `@MainActor` or `await MainActor.run`.
- **Storyboards / XIBs for new code** — SwiftUI or programmatic UIKit only; storyboards merge poorly and hide behaviour.
- **`@objc` chains exposing Swift internals** — every `@objc` is a concurrency hole and ABI hazard.
- **Mutating UI from background queues** — Swift 6 strict concurrency catches this; do not silence with `nonisolated(unsafe)`.
- **Combine where `async/await` suffices** — `AsyncSequence` covers most streaming with less ceremony.
- **`fatalError` as control flow** — only for genuinely unreachable branches; prefer typed throws.
- **Massive view models** — split by feature; a VM touching 8 services is a coordinator in disguise.
- **Hardcoded strings in views** — use `String(localized:)` and a strings catalog from day one.

## Test layer hierarchy

1. **Unit XCTest / Swift Testing on view models, services, mappers** — pure Swift, no `XCUIApplication`, no simulator boot. Default choice.
2. **SwiftUI snapshot tests (e.g. `swift-snapshot-testing`)** — pin layout for design-system components and critical screens. Fixed simulator for stable diffs.
3. **UI tests via XCUITest** — **LAST RESORT.** Reserve for end-to-end flows (sign-in, purchase, deep link). Slow, flaky-prone; keep small and tagged.

## Tactical testing rules

- Inject `Clock`, `UUID`, `URLSession` — never reach for the real ones inside business logic.
- Prefer protocol witnesses (struct of closures) over protocol+mock-class — fewer files, exact behaviour per test.
- Snapshot tests record on one device + appearance combo; record-mode commits should fail review unless intentional.
- XCUITest selectors use `accessibilityIdentifier`, never localized text.
- Async tests use `await fulfillment(of: [expectation])`; no `sleep`, no polling loops.

## Stack-specific gotchas

- iOS 16 deployment lacks `@Observable`; gate with `#if canImport(Observation)` or bump the minimum.
- `Task { @MainActor in ... }` inside a view body creates a fresh task on every render — hoist to `.task { }`.
- `@StateObject` vs `@ObservedObject` vs `@State` for `@Observable` differs; misuse causes lost state across rebuilds.
- App Store review still rejects private API usage and undeclared tracking — audit `PrivacyInfo.xcprivacy`.
- SwiftUI previews load a different process than the app — gate preview-only code with `#if DEBUG`.
- Swift 6 concurrency is opt-in per module; mixing strict + non-strict surfaces warnings only at the boundary.

## Performance / Accessibility baseline

- `.id()` to force-reset identity-changing views, `.equatable()` to skip diffs on stable subtrees.
- Profile with Instruments (Time Profiler, Allocations, SwiftUI) before optimizing — guesses lie.
- `LazyVStack` / `LazyHStack` / `List` for long content; never `ForEach` inside `ScrollView` for large sets.
- `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityValue` on every interactive element; group with `.accessibilityElement(children: .combine)`.
- Support Dynamic Type up to AX5; never hardcode font sizes — use `.font(.body)` and friends.
- Respect `@Environment(\.accessibilityReduceMotion)` for animations; provide a non-motion fallback.
- VoiceOver pass on every new screen before merge; contrast minimum 4.5:1 (3:1 for large text).
