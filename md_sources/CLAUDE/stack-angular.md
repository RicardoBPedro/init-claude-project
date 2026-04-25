# CLAUDE.md — Angular addendum

<!--
  Merged into CLAUDE.md when type=frontend and FRONTEND_FLAVOR=angular.
  Assumed stack: TypeScript + Angular 17+ (standalone components, signals, control flow) + Karma/Jasmine OR Jest.
  Optional: Cypress, Playwright, NgRx / Signal Store.
-->

Supplements core CLAUDE.md with Angular-specific best practices.

## Commands

```bash
ng serve                    # dev server
ng build                    # production build
ng test                     # Karma + Jasmine — single run via --watch=false --browsers=ChromeHeadless
npm run test                # if migrated to Jest
ng lint                     # ESLint via @angular-eslint
ng e2e                      # Cypress / Playwright depending on setup
npx tsc --noEmit            # standalone typecheck
npx prettier --check .      # format check
```

Single spec: `ng test --include="**/foo.component.spec.ts" --watch=false`.

## Idiomatic patterns (DO)

- **Signals over BehaviorSubject** for component state — `signal()`, `computed()`, `effect()`. Cleaner than RxJS for non-async state.
- **`ChangeDetectionStrategy.OnPush`** as default — make inputs immutable; signals make this automatic.
- **`inject()` for DI** — works in functions, guards, interceptors, field initializers.
- **New control flow** — `@if`, `@for (track item.id)`, `@switch` over `*ngIf`/`*ngFor`/`*ngSwitch`. Better narrowing, mandatory `track`.
- **`takeUntilDestroyed()`** for RxJS subscriptions — auto-unsubscribes. Pair with `inject(DestroyRef)` outside injection contexts.
- **`AsyncPipe` over manual `subscribe`** in templates — handles subscribe/unsubscribe and triggers OnPush updates.
- **`InjectionToken<T>` for non-class providers** — typed config, no `any` in DI.
- **`provideHttpClient(withInterceptors([...]))`** in `app.config.ts` — functional interceptors, no class boilerplate.
- **Reactive forms with typed `FormGroup`** — `new FormGroup<{ email: FormControl<string> }>(...)`. Template-driven only for trivial cases.

## Anti-patterns (AVOID — call out and fix when seen)

- **Function calls in templates** — `{{ getName() }}` runs every CD cycle. Use `computed()` or a cached getter.
- **Manual `subscribe()` without unsubscribe** — leaks. Use `AsyncPipe` or `takeUntilDestroyed()`.
- **Effects that trigger HTTP** — `effect()` is for sync side-effects (DOM, localStorage). HTTP belongs in handlers or resolvers.
- **`changeDetectorRef.detectChanges()` to "fix" stale UI** — symptom of a missing OnPush input or unsubscribed observable.
- **Mutating `@Input()` arrays/objects** — breaks OnPush. Emit a new reference.
- **Skipping `track` on `@for`** — Angular 17+ requires it; missing track means no key-based diffing.
- **Two-way binding (`[(ngModel)]`) on complex shapes** — prefer reactive forms.

## Test layer hierarchy

Pick the **lightest layer** where the rule reads naturally:

1. **Unit** — pure functions, services without HTTP, signals/computed in isolation. Default.
2. **Component integration** — `TestBed.configureTestingModule` with real templates + `provideHttpClientTesting()` (or MSW). No browser beyond ChromeHeadless.
3. **E2E** — Cypress / Playwright. **LAST RESORT.** Only for cross-service flows.

## Tactical testing rules

- Use `provideHttpClient(withInterceptors([...]))` + `provideHttpClientTesting()` over deprecated `HttpClientTestingModule`.
- `fakeAsync` + `tick()` for time-dependent code; never real `setTimeout` in tests.

## Stack-specific gotchas

- **`effect()` runs once on registration** — gate with a flag to skip initial run. Use `untracked()` to read without tracking.
- **Signal inputs (`input()`, `input.required()`)** are read-only — assign via parent binding.
- **Zoneless mode** (`provideExperimentalZonelessChangeDetection`) requires signals or manual `markForCheck`.
- **`HttpClient` in interceptors** — circular DI. Use `HttpBackend` to call HTTP from an interceptor.
- **Route resolvers run before the component** — heavy work belongs there, not in `ngOnInit`.

## Accessibility / UI verification (for frontend stacks)

- `aria-label` on every interactive element without a visible label.
- Keyboard navigation: Tab, Enter, Space, Escape — all work.
- WCAG AA contrast: 4.5:1 body text, 3:1 large text, 3:1 UI components.
- Visible focus ring on every focusable element.
- `<label for="...">` bound to every form input.
- For dynamic content, use `cdkLiveAnnouncer` / `aria-live` regions.
