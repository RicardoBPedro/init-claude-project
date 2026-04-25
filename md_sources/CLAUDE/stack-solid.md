# CLAUDE.md — SolidJS addendum

<!--
  Merged into CLAUDE.md when type=frontend and FRONTEND_FLAVOR=solid.
  Assumed stack: TypeScript + SolidJS 1.8+ + Vite + Vitest + @solidjs/testing-library.
  Optional: Solid Start (SSR/meta-framework), Solid Router, Playwright.
-->

Supplements core CLAUDE.md with Solid-specific best practices.

## Commands

```bash
npm run dev           # Vite dev server (Solid Start: vinxi dev)
npm run build         # production build
npm run test          # Vitest single run
npm run test:coverage # coverage report
npm run lint          # ESLint
npm run typecheck     # tsc --noEmit
npm run format        # Prettier
npm run test:e2e      # Playwright
```

Single file: `npx vitest run <path>`.

## Idiomatic patterns (DO)

- **Signals are functions — call to read** — `const [count, setCount] = createSignal(0); count()` reads, `setCount(1)` writes. Not React state.
- **`createMemo` for derived values** — caches computation tied to its signal deps: `const doubled = createMemo(() => count() * 2)`.
- **`createEffect` for side-effects only** — DOM, network, subscriptions. Tracks signals read inside.
- **`createStore` + `produce` for nested state** — `setStore('user', 'name', 'Ana')` or `setStore(produce(s => { s.user.name = 'Ana' }))`. Fine-grained reactivity through paths.
- **`<For each={items()}>{item => ...}</For>` over `.map`** — keyed by reference, only diffs changed rows. `<Index>` for index-keyed.
- **`<Show when={cond()} fallback={...}>`** over `cond() && <X />` — preserves DOM identity, supports fallbacks.
- **`<Switch><Match when={...} />` for n-way conditions** — type-narrowing and clear branches.
- **`splitProps` to forward props** — `const [local, others] = splitProps(props, ['class'])` keeps reactivity intact.
- **`onCleanup` inside effects/components** — register teardown for subscriptions, intervals, listeners.

## Anti-patterns (AVOID — call out and fix when seen)

- **Destructuring props** — `function Btn({ label }) {...}` reads `label` once at creation; never updates. Use `props.label`.
- **`cond() && <X />` for conditional rendering** — creates and destroys DOM on every change. Use `<Show>`.
- **Treating signals like values** — `count + 1` is `[Function] + 1`. Always call: `count() + 1`.
- **`createEffect` for derived state** — an effect that calls `setOther(...)` is a recompute loop. Use `createMemo`.
- **Mutating store state directly** — `store.user.name = 'x'` doesn't notify. Use `setStore(...)` or `produce`.
- **`.map()` over reactive arrays** — re-renders all rows on any change. Use `<For>`.
- **Sharing state via module-level mutable variables** — won't notify. Export a signal/store from the module.
- **`onMount` for tracked work** — runs once, doesn't track. Use `createEffect` for re-runs on signal change.

## Test layer hierarchy

Pick the **lightest layer** where the rule reads naturally:

1. **Unit** — pure functions, signals/stores via `createRoot(dispose => {...})`, isolated components via `@solidjs/testing-library`. Default.
2. **Component integration** — Testing Library + MSW for components that fetch. No browser.
3. **E2E** — Playwright. **LAST RESORT.** Only for SSR flows (Solid Start) and cross-service journeys.

## Tactical testing rules

- Wrap signal/store tests in `createRoot(dispose => { ...; dispose() })` to ensure effect cleanup.
- Use `@solidjs/testing-library`'s `render()` — automatic cleanup between tests.

## Stack-specific gotchas

- **Components run once** — function body is the "constructor"; only JSX expressions and effects re-run on change.
- **`createResource` returns a signal** — `data()` reads the value; `data.loading` and `data.error` are accessors too.
- **`Show` with `keyed` prop** — `<Show keyed when={user()}>` re-creates DOM on reference change; without `keyed` it keeps DOM and updates.
- **SSR (Solid Start) hydration** — markup must match server output exactly; conditional rendering on `isServer` requires `<NoHydration>` or `clientOnly`.
- **Refs are callbacks or via `let el!: HTMLDivElement`** — accessed after mount; reading before mount is `undefined`.
- **Context in Solid is reactive** — providers pass signals/stores, not snapshots. Consumers re-run on changes.

## Accessibility / UI verification (for frontend stacks)

- `aria-label` on every interactive element without a visible label.
- Keyboard navigation: Tab, Enter, Space, Escape — all work.
- WCAG AA contrast: 4.5:1 body text, 3:1 large text, 3:1 UI components.
- Visible focus ring on every focusable element.
- `<label for="...">` bound to every form input.
