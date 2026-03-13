# Investigation Strategies Reference

> Load this reference during Step 1.4 (after extracting initial leads) to select the appropriate investigation strategy. Each strategy prescribes a specific investigation order, what to look for, and when to stop.

## Bug Category Classification

Classify the bug into one of these categories before selecting a strategy. The category determines which investigation strategy to follow.

| Category | Signals | Example |
|----------|---------|---------|
| `runtime-error` | Stack trace, exception message, crash report | `TypeError: Cannot read properties of undefined` |
| `logic-bug` | Wrong output, incorrect behavior, bad calculation | "The discount applies twice" |
| `type-error` | Type mismatch, serialization failure, schema violation | `Expected string, received number` |
| `ui-visual` | Layout broken, styling wrong, responsive issue | "Button overlaps the sidebar on mobile" |
| `ui-behavioral` | Click/interaction doesn't work, wrong navigation, state issue | "Form submits but nothing happens" |
| `performance` | Slow response, memory leak, high CPU, timeout | "Page takes 10s to load" |
| `data-integrity` | Wrong data in DB, lost records, duplicate entries | "User's email changed to null after update" |
| `integration-failure` | External API error, webhook failure, auth rejection | "Stripe webhook returns 401 since deploy" |
| `intermittent` | Sometimes works, sometimes doesn't — timing/race/env dependent | "Login fails about 30% of the time" |
| `build-compile` | Build error, compilation failure, dependency conflict | `Module not found: @org/package` |
| `security` | Auth bypass, data leak, permission escalation | "Unauthenticated users can access /admin" |

If the bug doesn't clearly fit one category, use `runtime-error` as the default — it has the broadest investigation strategy.

Record the category in `initial_leads.bug_category`.

---

## Strategy: Runtime Error

**Trigger:** Stack trace or exception message present in bug report.

**Investigation order:**

1. **Parse the stack trace** — Extract file paths and line numbers. The top frame is the crash site; deeper frames show the call chain.
2. **Read the crash site** — Read the file/line from the top stack frame. Understand what operation was attempted.
3. **Check the input** — What data flows into the crashing function? Read the caller (next frame up) to see what arguments were passed.
4. **Trace the data origin** — Follow the data backward: where was it created, transformed, or fetched? Look for null/undefined injection points.
5. **Check recent changes** — `git blame` on the crash site and its callers. Was this code recently modified?
6. **Check error handling** — Is there a try/catch or error boundary that should have caught this? Was it bypassed?

**Max file depth:** 15 files
**When to stop:** When you can identify the exact line where invalid data enters the system, or when you've traced 3 levels of callers without finding the injection point (return partial).

---

## Strategy: Logic Bug

**Trigger:** Behavior is wrong but no crash — the code runs but produces incorrect results.

**Investigation order:**

1. **Identify the output** — Where does the wrong value/behavior surface? (API response, UI render, database write)
2. **Read the producing function** — Find the function that generates the wrong output. Read it completely.
3. **Check the conditional logic** — Look for: inverted conditions, off-by-one errors, missing edge cases, operator precedence, short-circuit evaluation mistakes.
4. **Trace input values** — What inputs produce the wrong output? Follow them backward through transformations.
5. **Check business rules** — Read the playbook/architecture docs for the expected behavior. Is the code implementing the wrong rule, or the right rule incorrectly?
6. **Check test coverage** — Do existing tests cover this case? If tests pass but behavior is wrong, the tests may encode the wrong expectation.
7. **Compare with similar code** — Use the capability-map to find similar functions. Do they handle the same pattern differently?

**Max file depth:** 20 files (logic bugs often require broader context)
**When to stop:** When you can identify the specific conditional or transformation that produces the wrong result, or when you've exhausted the data flow path (return partial).

---

## Strategy: Type Error

**Trigger:** Type mismatch, serialization error, schema validation failure.

**Investigation order:**

1. **Identify the boundary** — Where does the type mismatch occur? (API request/response, database read/write, function call, JSON parse)
2. **Read both sides of the boundary** — What type does the producer send? What type does the consumer expect?
3. **Check type definitions** — Read the TypeScript interfaces, Python type hints, Go structs, or schema definitions for both sides.
4. **Check serialization** — Is there a JSON.parse/stringify, ORM mapping, or API serialization step that transforms the type?
5. **Check for implicit coercion** — Language-specific: JS loose equality, Python truthy/falsy, Go interface assertions.
6. **Check recent schema changes** — `git log` on type definition files and migration files.

**Max file depth:** 12 files (type errors are usually localized to a boundary)
**When to stop:** When you can identify the producer/consumer mismatch, or when you've checked all boundaries in the data path.

---

## Strategy: UI Visual

**Trigger:** Layout, styling, or visual rendering issue.

**Investigation order:**

1. **Identify the component** — Which component renders the broken UI? Check the route/page structure.
2. **Read the component** — Read the full component file including styles (CSS modules, styled-components, Tailwind classes, inline styles).
3. **Check the style cascade** — Look for: conflicting CSS specificity, missing responsive breakpoints, `!important` overrides, z-index stacking issues.
4. **Check design tokens** — Is the component using hardcoded values instead of design tokens? Read the style-guide doc.
5. **Check parent layout** — Read the parent component's layout (flex/grid container). The bug may be in the container, not the child.
6. **Check conditional rendering** — Is a wrapper div or CSS class conditionally applied? Check the render conditions.
7. **Check recent CSS changes** — `git log` on the component file and any shared stylesheet.

**Max file depth:** 10 files (visual bugs are typically localized)
**When to stop:** When you can identify the CSS rule, layout property, or missing class causing the visual defect.

---

## Strategy: UI Behavioral

**Trigger:** User interaction doesn't work, wrong navigation, broken form, state management issue.

**Investigation order:**

1. **Identify the interaction handler** — Find the onClick, onSubmit, onChange, or event handler for the broken interaction.
2. **Read the handler** — Follow the handler's execution: state updates, API calls, navigation.
3. **Check state management** — Read the relevant state (useState, Redux store, context, Zustand store). Is state being updated correctly? Race conditions between state updates?
4. **Check the re-render cycle** — Is the component re-rendering when state changes? Check for: stale closures, missing dependency arrays in useEffect/useMemo, incorrect memoization.
5. **Check API integration** — If the handler calls an API: read the API call, check the response handling, check error handling.
6. **Check routing** — If navigation is involved: read the route configuration, check for guards/middleware.
7. **Check event propagation** — Is stopPropagation or preventDefault used correctly? Is there an event listener conflict?

**Max file depth:** 15 files
**When to stop:** When you can identify the broken state transition or handler logic.

---

## Strategy: Performance

**Trigger:** Slow response, memory issues, timeout.

**Investigation order:**

1. **Identify the slow path** — Which endpoint, page, or operation is slow?
2. **Read the handler/component** — Look for: N+1 queries, missing pagination, unbounded loops, large data transformations in memory.
3. **Check database queries** — Read the query or ORM call. Look for: missing indexes (check migration files), full table scans, unnecessary JOINs, SELECT * on large tables.
4. **Check caching** — Is there a cache layer? Read it. Is it being bypassed? Expired? Returning stale data?
5. **Check external calls** — Are there synchronous calls to external services in the hot path? Missing timeouts? Sequential calls that could be parallel?
6. **Check data volume** — Is the code designed for small data but running against large data? Look for in-memory sorting/filtering of large sets.
7. **Check recent changes** — `git log` to identify when the slowdown started. Compare the before/after code.

**Max file depth:** 20 files
**When to stop:** When you can identify the computational bottleneck or inefficient data access pattern.

---

## Strategy: Data Integrity

**Trigger:** Wrong data in storage, lost records, duplicates.

**Investigation order:**

1. **Identify the write path** — Which code writes to the affected data? Trace from the user action to the database write.
2. **Check transactions** — Is the write inside a transaction? Can partial failures leave inconsistent state?
3. **Check concurrent writes** — Are there race conditions? Multiple processes writing the same record? Missing optimistic/pessimistic locking?
4. **Check cascade effects** — Are there triggers, hooks, or cascading updates that modify related data?
5. **Check migration history** — `git log` on migration files. Was a recent migration destructive or did it change column types/defaults?
6. **Check validation** — Is input validated before write? Could invalid data bypass validation?
7. **Check the read path** — Is the data actually wrong in storage, or is the read path transforming it incorrectly?

**Max file depth:** 15 files
**When to stop:** When you can identify the write operation that produces incorrect data, or the missing transaction/lock that allows corruption.

---

## Strategy: Integration Failure

**Trigger:** External service error, webhook failure, auth rejection.

**Investigation order:**

1. **Check the error response** — What does the external service return? (HTTP status, error body, error code)
2. **Read the integration code** — Find the service client/wrapper. Check: URL construction, headers, authentication, request body format.
3. **Check credentials/config** — Look for environment variable references. Are the right credentials being used? Have they expired or been rotated?
4. **Check API versioning** — Is the code calling a deprecated API version? Check the external service's changelog (web research may help here).
5. **Check request/response mapping** — Is the request body formatted correctly for the external API's current schema?
6. **Check error handling** — Is the error being caught and handled, or is it bubbling up raw?
7. **Check recent dependency updates** — `git log` on package.json/lock files. Did an SDK update change the API surface?
8. **Web research** — Search for the specific error code + service name. This is a high-value web research scenario — external services have known issues, breaking changes, and migration guides.

**Max file depth:** 12 files
**When to stop:** When you can identify the API contract violation or configuration error.

---

## Strategy: Intermittent Bug

**Trigger:** Bug is not reliably reproducible — happens sometimes, depends on timing, load, or environment.

**Investigation order:**

1. **Identify the variable** — What changes between "works" and "doesn't work"? (timing, data, user, load, environment)
2. **Check for race conditions** — Look for: shared mutable state, missing locks/mutexes, async operations without proper awaiting, event ordering assumptions.
3. **Check for timing dependencies** — setTimeout/setInterval, debounce/throttle, connection pool exhaustion, cache TTL edge cases.
4. **Check for environmental differences** — Environment variables, feature flags, A/B tests, regional config.
5. **Check error handling paths** — Intermittent bugs often hide in error recovery paths. What happens when a retry kicks in? When a connection drops?
6. **Check for resource limits** — Connection pool size, file descriptor limits, memory pressure, rate limiting.
7. **Use git bisect strategy** — If the user knows "it worked last week": identify the commit range and check for suspicious changes.

**Max file depth:** 20 files (intermittent bugs require broader investigation)
**When to stop:** When you can identify the race condition, timing dependency, or environmental factor. If you cannot, return `partial` with the narrowed-down suspect area — intermittent bugs often need runtime instrumentation to confirm.

---

## Strategy: Build/Compile Error

**Trigger:** Build failure, compilation error, module resolution failure.

**Investigation order:**

1. **Parse the error message** — Extract the file, line, and error code.
2. **Read the failing file** — Check the line referenced in the error.
3. **Check imports/dependencies** — Is the missing module installed? Check package.json/requirements.txt/go.mod. Check lock file for version mismatches.
4. **Check configuration** — Read build config (tsconfig, webpack, vite, babel, etc.). Check for recent changes.
5. **Check for circular dependencies** — Trace imports between the failing file and its dependencies.
6. **Check recent dependency updates** — `git log` on lock files. Did a dependency update break something?
7. **Web research** — Build errors with specific dependency versions are prime candidates for web research — others have likely hit the same issue.

**Max file depth:** 10 files (build errors are usually localized)
**When to stop:** When you can identify the misconfiguration, missing dependency, or version conflict.

---

## Strategy: Security Bug

**Trigger:** Authentication bypass, authorization failure, data exposure.

**Investigation order:**

1. **Identify the vulnerability surface** — Which endpoint, page, or operation is affected?
2. **Read the auth middleware** — Check the authentication and authorization chain for the affected route.
3. **Check middleware ordering** — Is the auth middleware applied before the route handler? Is it applied at all?
4. **Check authorization logic** — Read the permission check. Look for: missing role checks, inverted conditions, bypass paths.
5. **Check data exposure** — Are sensitive fields being filtered from responses? Check serialization and API response shaping.
6. **Check input validation** — Is there SQL injection, XSS, or path traversal risk in the affected path?
7. **Check recent changes** — `git log` on auth/middleware files. Was a refactor or new route added without the auth guard?

**Max file depth:** 15 files
**When to stop:** When you can identify the missing or broken security control. Security bugs should err on the side of returning `partial` rather than `failed` — even partial findings are valuable for security issues.

---

## Area-Specific Investigation Patterns

### Frontend Investigations

In addition to the strategy-specific steps, always check:
- **Browser DevTools equivalent**: Think about what DevTools would show — network requests, console errors, DOM state
- **Component tree**: Read the component hierarchy from route down to the affected component
- **CSS specificity**: When styles are wrong, check for specificity wars across CSS modules, global styles, and third-party CSS
- **Hydration mismatches** (SSR frameworks): If using Next.js, Nuxt, etc. — check for server/client rendering differences
- **State management scope**: Is state local (useState), lifted (context/props), or global (Redux/Zustand)? The bug source depends on scope.

### Backend Investigations

In addition to the strategy-specific steps, always check:
- **Middleware chain**: Read the full middleware stack for the affected route — auth, validation, rate limiting, logging
- **Error response format**: Is the error being returned in the project's standard format, or is a raw/unformatted error leaking?
- **Database connection lifecycle**: Is the connection being properly acquired and released? Check for connection pool exhaustion.
- **Async error handling**: Are promises properly awaited? Are async errors caught? (unhandled rejection / uncaught exception)

### Fullstack Investigations

When the bug spans frontend and backend:
1. **Start at the boundary** — Read the API call from the frontend and the route handler on the backend
2. **Check the contract** — Do request/response shapes match? Check types on both sides.
3. **Trace in both directions** — From the API boundary, trace backward into the backend (data source) and forward into the frontend (rendering)
4. **Check for environment differences** — Base URLs, CORS, proxy config, environment variables that differ between frontend and backend

---

## Git Forensics

### When to use git commands

Git forensics is not always needed. Use it when:
- The user says "it used to work" or "it broke after [event]"
- The bug is in code that appears correct — suggests a recent regression
- The root cause isn't obvious from reading the current code
- You need to understand the intent behind a suspicious code pattern

### Prescribed commands

**Recent changes to a file:**
```bash
git log --oneline -10 -- [file_path]
```
Shows the last 10 commits touching this file. Look for recent changes that could introduce the bug.

**Who last changed a specific line:**
```bash
git blame -L [start],[end] -- [file_path]
```
Identifies the commit that last modified the suspect lines. Read the commit message for context.

**What changed in a specific commit:**
```bash
git show [commit_hash] --stat
git show [commit_hash] -- [file_path]
```
Shows the full diff of a suspect commit. Useful when `blame` points to a recent change.

**Regression hunting (when "it worked before"):**
```bash
git log --oneline --since="[date]" -- [file_path]
git log --oneline --since="[date]" -- [directory/]
```
Narrows the commit range where the regression was introduced. Use the date the user reports the bug started.

**Finding when a line was introduced:**
```bash
git log -S "[code string]" --oneline
```
Searches git history for when a specific string was added or removed. Useful for tracking down when a bug-causing line was introduced.

**Comparing file between commits:**
```bash
git diff [older_commit]..[newer_commit] -- [file_path]
```
Direct comparison of a file between two points in history.

### Git forensics limits

- Run at most **5 git commands** per investigation
- Do not run `git log` without path filters on large repos (unbounded output)
- Do not run `git bisect` (interactive — not supported in this context)
- Record every command run in `investigation.git_forensics.commands_run`

---

## Web Research

### When to use web research

Web research is a **secondary investigation tool** — source code analysis is always primary. Use web research when:

1. **Framework/library bug suspected** — The code appears correct but the behavior is wrong, suggesting the bug is in a dependency, not the project's code
2. **Specific error code from external service** — Error codes from APIs (Stripe, AWS, GitHub, etc.) are best understood via their official documentation
3. **Build/dependency errors with version numbers** — Specific version conflicts often have known solutions documented in issues/discussions
4. **Deprecated API or breaking change** — When a dependency was recently updated and the error suggests an API surface change
5. **Cryptic error messages** — Errors from compiled/minified code, native modules, or complex frameworks that don't have clear source code paths

### When NOT to use web research

- **The bug is clearly in the project's own code** — You can see the defect. Don't search for it.
- **The error message is self-explanatory** — `Cannot read property 'name' of undefined` doesn't need a web search.
- **As a first resort** — Always read the code first. Web research fills gaps that source code analysis cannot.
- **To find "how to fix" recipes** — The debugger identifies root causes. The fix approach is the planner's job.

### How to conduct web research

1. **Search first, fetch second** — Use web search to find relevant pages, then fetch specific pages for details.
2. **Prefer official sources** — Framework docs, GitHub issues on the relevant repo, official migration guides. Avoid random blog posts or Stack Overflow answers unless from authoritative users.
3. **Include version numbers** — Always include the framework/library version in search queries. A fix for v14 may not apply to v15.
4. **Record everything** — Log all queries and findings in `investigation.web_research`. The orchestrator and planner benefit from knowing what was found.
5. **Limit scope** — Maximum **3 web searches** and **5 page fetches** per investigation. If you haven't found what you need in that budget, the web research path is likely not productive.

### Structuring web research findings

```json
{
  "query": "nextjs 14 hydration mismatch useEffect",
  "source": "https://nextjs.org/docs/messages/react-hydration-error",
  "finding": "Next.js 14 requires wrapping browser-only code in useEffect or dynamic() with ssr:false",
  "relevance": "high | medium | low",
  "applies_to_bug": true,
  "recommended_action": "Known framework behavior — the fix is to wrap the date formatting in useEffect"
}
```

When web research reveals the bug is a **known framework issue with a documented workaround**:
- Set `root_cause.type` to `"framework-known-issue"` in the fix description
- Include the workaround in `fix_description` with a link to the official documentation
- Add a constraint: `"workaround for [framework] [issue] — may be resolved in future version [X]"`
- Set the appropriate acceptance criterion to verify the workaround works

When web research reveals the bug is caused by a **dependency version change**:
- Record the breaking version range
- Include the version constraint in `fix_description`
- Add both "fix the code" and "pin the dependency" as options for the planner to evaluate

---

## Investigation Bounding Rules

### File read limits

Each strategy prescribes a `max_files` limit. These are guidelines, not hard stops — but exceeding them by more than 5 files requires justification.

| Scenario | Max Files | Rationale |
|----------|-----------|-----------|
| Strategy default | Varies (10-25) | Prescribed per bug category |
| Missing documentation | Strategy max + 5 | Extra files to compensate for no capability-map/playbook |
| Fullstack bug | Strategy max + 5 | Need to read both frontend and backend |
| Hard limit (never exceed) | 30 | Context budget — beyond this, return partial |

### Lead prioritization

When multiple investigation leads exist, follow them in this order:

1. **Direct evidence** — Stack trace points to a file/line → read it immediately
2. **Data origin** — The data feeding the crash site → trace backward one hop
3. **Recent changes** — `git blame` on crash site → check if recently modified
4. **Related code** — Callers, tests, similar functions → broaden understanding
5. **Configuration** — Env vars, config files, feature flags → check for environmental causes
6. **External factors** — Dependencies, external services → last resort before web research
7. **Web research** — Only after source code paths are exhausted

### When to abandon a lead

Abandon a lead (and record in `investigation.depth.leads_abandoned`) when:
- You've read 3+ files on a lead with no evidence supporting it
- The lead points to code that hasn't changed in 6+ months and the bug is recent
- The lead requires runtime data that cannot be inferred from static analysis
- A higher-priority lead emerges while following a lower-priority one

### When to return partial

Return `status: "partial"` (don't push to `failed`) when:
- You have at least one hypothesis with evidence, but confidence is `medium` or `low`
- You've hit the file read limit without finding the exact root cause
- The bug requires runtime instrumentation to confirm (race conditions, intermittent issues)
- The code path involves dynamically loaded/generated code that can't be traced statically

Return `status: "failed"` only when:
- You have zero hypotheses after exhausting the investigation budget
- The bug report contains no actionable information (no error, no reproduction steps, no affected area)
- The relevant source code is inaccessible (compiled, minified, in a dependency with no source maps)

---

## Stack-Aware Debugging

Rather than duplicating stack-specific knowledge, the debugger should read the relevant stack reference from `skills/ws-codebase-documenter/references/stacks/` to understand:
- **File organization patterns** — Where to find source code, tests, config, and entry points for the detected stack
- **Public/private API conventions** — Helps trace which functions are called from where
- **Module systems** — Import/export patterns affect how code paths connect

Detect the stack from project root files:

| Files Present | Stack | Reference |
|--------------|-------|-----------|
| `package.json`, `tsconfig.json` | Node.js/TypeScript | `stacks/nodejs.md` |
| `pyproject.toml`, `setup.py`, `requirements.txt` | Python | `stacks/python.md` |
| `go.mod` | Go | `stacks/go.md` |
| `Cargo.toml` | Rust | `stacks/rust.md` |
| `*.csproj`, `*.sln` | .NET | `stacks/dotnet.md` |
| `pom.xml`, `build.gradle` | Java | `stacks/java.md` |
| `composer.json` | PHP | `stacks/php.md` |

### Stack-specific error patterns

These common patterns accelerate investigation. If the error matches a known pattern, start the investigation there:

**Node.js/TypeScript:**
- `TypeError: Cannot read properties of undefined/null` → null reference chain, trace the variable origin
- `ERR_MODULE_NOT_FOUND` → import path error, check tsconfig paths and package.json exports
- `ECONNREFUSED` → service not running or wrong port, check config
- `UnhandledPromiseRejection` → missing await or .catch(), check async call chain
- Hydration errors (Next.js/Remix) → server/client mismatch, check for browser-only APIs in SSR path

**Python:**
- `AttributeError: 'NoneType' has no attribute` → null reference, trace the variable
- `ImportError` / `ModuleNotFoundError` → dependency or path issue, check virtualenv and installed packages
- `IntegrityError` → database constraint violation, check model constraints and migration
- `RecursionError` → infinite loop or recursive call, check base cases
- `asyncio.TimeoutError` → async operation exceeded timeout, check external calls

**Go:**
- `panic: runtime error: invalid memory address or nil pointer dereference` → nil pointer, trace the pointer chain
- `context deadline exceeded` → timeout on context, check context propagation
- `connection refused` → service unavailable, check ports/config
- Data race (detected by `-race`) → concurrent map/slice access without mutex

**General patterns:**
- `CORS` errors → backend missing CORS headers, check middleware config
- `401`/`403` → auth token expired, missing, or insufficient permissions, check auth middleware
- `500` with no details → unhandled exception, check error middleware and logging config
- Connection timeout → network config, firewall, or resource exhaustion
