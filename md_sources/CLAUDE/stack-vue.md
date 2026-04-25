# CLAUDE.md — Vue addendum

<!--
  Merged into CLAUDE.md when type=frontend and FRONTEND_FLAVOR=vue.
  Assumed stack: TypeScript + Vue 3 (Composition API, <script setup>) + Vite + Vitest + @vue/test-utils.
  Optional: Nuxt 3, Pinia, Cypress, Playwright.
-->

Supplements core CLAUDE.md with Vue-specific best practices.

## Commands

```bash
npm run dev               # Vite dev server (Nuxt: nuxt dev)
npm run build             # production build
npm run test              # Vitest single run
npm run test:coverage     # coverage report
npm run lint              # ESLint (eslint-plugin-vue)
npm run typecheck         # vue-tsc --noEmit
npm run format            # Prettier
npm run cypress:run       # headless E2E
npm run test:a11y         # Playwright + axe
```

Single file: `npx vitest run <path>`.

## Idiomatic patterns (DO)

- **`defineProps<Props>()` + `withDefaults`** — `withDefaults(defineProps<Props>(), { count: 0 })`.
- **`defineModel()` for two-way binding** (Vue 3.4+) — replaces `props` + `emit('update:modelValue')` boilerplate.
- **`ref` for primitives, `reactive` for stable shapes** — never reassign `reactive`; replace properties or use `ref`.
- **`computed` for derived, `watch` for side-effects** — never set state in a watcher via `.value = ...`.
- **`storeToRefs`** when destructuring a Pinia store — keeps reactivity.
- **`provide`/`inject` with `InjectionKey<T>`** — typed cross-component dependencies without prop drilling.
- **`defineEmits<{ change: [value: string] }>()`** — always type emits.

## Anti-patterns (AVOID — call out and fix when seen)

- **Mixins** — implicit name collisions, unclear data flow. Use composables.
- **Mutating props** — read-only. `emit` an event or use `defineModel`.
- **Forgetting `.value` on refs in script** — passes the ref object instead of the value. TypeScript catches this; don't suppress.
- **Reassigning `reactive` objects** — `state = newState` breaks reactivity. Use `Object.assign(state, newState)` or `ref`.
- **Watcher chains** — A sets B which triggers C. Refactor into `computed` or one composable.
- **`v-if` + `v-for` on same element** — Vue 3 errors; split into a wrapper or filter via `computed`.
- **Index as `:key` in mutable lists** — input state leaks on reorder. Use a stable id.
- **Heavy logic in templates** — push to `computed` or methods.

## Test layer hierarchy

Pick the **lightest layer** where the rule reads naturally:

1. **Unit** — pure functions, composables called directly, isolated SFCs via `@vue/test-utils` + Vitest. Default.
2. **Component integration** — `mount()` with `createTestingPinia()` + provide/inject + MSW. No browser.
3. **E2E** — Cypress / Playwright. **LAST RESORT.** Only for cross-service flows mocks can't fake.

## Tactical testing rules

- Test composables by calling `useX()` directly — not via wrapper components.
- Mock Pinia stores via `createTestingPinia({ initialState })`.

## Stack-specific gotchas

- **`flush: 'post'` for DOM-reading watchers** — default `'pre'` runs before render; `offsetHeight` reads stale.
- **`shallowRef` for large immutable trees** — full `ref` makes every nested property reactive.
- **Nuxt `useFetch` runs on server + client** — guard with `process.server` or use `$fetch` client-only.
- **`<Suspense>` + async `setup`** — one async setup per boundary; nest for granular fallbacks.
- **Teleport + tests** — content lives outside the wrapper. Query via `document` or `attachTo: document.body`.

## Accessibility / UI verification (for frontend stacks)

- `aria-label` on every interactive element without a visible label.
- Keyboard navigation: Tab, Enter, Space, Escape — all work.
- WCAG AA contrast: 4.5:1 body text, 3:1 large text, 3:1 UI components.
- Visible focus ring on every focusable element.
- `<label>` bound to every form input.
