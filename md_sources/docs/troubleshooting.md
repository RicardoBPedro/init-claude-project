# Troubleshooting

Recurring issues that block development. Check here before filing a "works on my machine" bug or spending an hour debugging.

## Environment

### Windows + Git Bash path issues

**Symptom:** scripts fail with `No such file or directory` on paths like `/c/Users/...` or `C:\Users\...`.

**Cause:** Windows paths have three forms (`C:\Users\`, `C:/Users/`, `/c/Users/`) depending on shell. Git Bash accepts all three but passes them to child processes inconsistently.

**Fix:** always use forward-slash form (`/c/Users/...` or `C:/Users/...`) in scripts. Avoid backslashes except in Windows-native commands (`cmd.exe`, `powershell.exe`).

### Windows + Docker Desktop context

**Symptom:** Testcontainers, `docker compose up`, or any Docker-based operation hangs indefinitely on Windows.

**Cause:** Docker Desktop's default context on Windows is `default`, which uses the legacy Named Pipe socket (`npipe:////./pipe/docker_engine`). Testcontainers' Ryuk cleanup agent can't connect through it reliably.

**Fix:** switch to `desktop-linux` (Unix-socket bridge into Docker Desktop's Linux VM).

```bash
docker context show            # check current
docker context use desktop-linux
```

For scoped fixes (don't change the user's global default), prefix the invocation:

```bash
DOCKER_CONTEXT=desktop-linux ./gradlew test
```

The `scripts/test-backend.sh` wrapper does this automatically.

### Windows + line endings (CRLF vs LF)

**Symptom:** shell scripts fail with `\r: command not found` or hooks silently skip.

**Cause:** git on Windows auto-converts `.sh` files to CRLF on checkout. Bash can't parse CRLF shebangs.

**Fix:** `.gitattributes` with `*.sh text eol=lf` pins LF for shell scripts. The installer generates this.

## Tests

### Zombie Testcontainers after killed gradle run

**Symptom:** next `./gradlew test` hangs for 15+ minutes with no output, then fails.

**Cause:** if a gradle test run is interrupted (Ctrl+C, agent TaskStop, IDE crash), Ryuk doesn't get the chance to clean up its children. Leftover Postgres + Ryuk containers block the next run.

**Fix:**

```bash
docker ps --filter ancestor=postgres --filter ancestor=testcontainers/ryuk -q | xargs -r docker stop
./gradlew --stop
```

If that doesn't clear it:

```bash
docker ps -a --filter ancestor=testcontainers/ryuk -q | xargs -r docker rm -f
```

### Scheduler tests flaky on slow CI

**Symptom:** `@Scheduled` or similar tests pass locally, fail on CI or under load.

**Cause:** wall clock leaked into test assertions (e.g. `Instant.now()` in production code, not injectable).

**Fix:** inject `Clock` (Spring bean, not `Instant.now()`). In tests, bind `Clock.fixed(Instant.parse("..."), ZoneOffset.UTC)`. Testing standard rule: time must be injectable. No exceptions.

### Coverage report shows unexpected drop

**Symptom:** PR fails coverage gate, diff shows no obvious new uncovered paths.

**Cause:** usually one of:
1. New branch in existing method without a test for the new path.
2. Test that used to cover a method was renamed or removed without replacement.
3. Instrumentation config drift (jacoco exclusions, vitest include patterns).

**Fix:** compare coverage HTML report before/after the change. Find the specific class/function that dropped. Don't lower the threshold — that's a ratchet.

## Git

### Branch accidentally created from an outdated main

**Symptom:** PR shows dozens of unrelated file changes, massive diff vs target.

**Cause:** local main was stale when the branch was created. `git checkout -b feat/xyz` from outdated main = branch diverges immediately.

**Fix:** always `git fetch && git checkout main && git pull --ff-only` before `git checkout -b`. `scripts/branch-start.sh` enforces this. For an already-polluted branch, rebase onto updated main: `git rebase origin/main`.

### Branch hygiene reports stale branches

**Symptom:** `bash scripts/branch-hygiene.sh` lists branches older than `STALE_DAYS`.

**Fix per branch:**
- Still relevant → rebase onto latest main, continue work, push.
- Abandoned → `git branch -D <branch>` (local) + delete from forge if pushed.
- Merged upstream but local copy lingering → `git branch -d <branch>` (safe delete).

Never bulk-delete without inspecting each. Lost work is worse than a messy branch list.

### Husky hook silently doesn't run

**Symptom:** commit goes through despite a pre-commit rule that should have blocked it.

**Cause:** one of:
1. `.husky/_/` not installed (`npx husky install` never ran).
2. Hook file not executable (`chmod +x .husky/pre-commit`).
3. Committed via `--no-verify` (blame the commit author).
4. Hook file has CRLF line endings (Windows).

**Fix:** `npx husky install` + `chmod +x .husky/*` + confirm `.gitattributes` pins LF for `.sh`.

## Claude Code

### SessionStart hook doesn't fire

**Symptom:** new session starts, no branch hygiene report surfaces.

**Cause:** `.claude/settings.json` hook path is wrong (absolute path to a different project, or forward-slash issue on Windows).

**Fix:** the path in the hook command must match the current project's absolute path. The installer substitutes `__PROJECT_ROOT__` with the absolute path at install time. Re-run the installer if the project was moved.

### `claude` CLI not found

**Symptom:** `claude: command not found` or the IDE extension can't reach the CLI.

**Fix:** install via npm:

```bash
npm install -g @anthropic-ai/claude-code
```

Or via the official installer. Verify with `claude --version`.

### MCP server fails to authenticate

**Symptom:** MCP tools show "needs authentication" in the agent picker.

**Fix:** run the `authenticate` tool for that server (e.g., `mcp__plugin_vercel_vercel__authenticate`). The Claude Code UI surfaces a link to complete OAuth. Tokens cache in `~/.claude/mcp-needs-auth-cache.json`.

## When to add to this file

New entry criteria:
- Issue recurs across projects or developers.
- Root cause is non-obvious from the symptom.
- Fix is specific enough to write down (not just "google it").

Not worth adding:
- One-off incidents with a unique root cause.
- Issues fixed by a version bump (note it in CHANGELOG instead).
- Anything that belongs in a library's own docs.
