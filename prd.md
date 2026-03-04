---

# PRD: WS AI Master Plan — Orchestrated Development & Prescriptive Documentation

## Document Info

- **Author**: Marc (CIO, Wondersauce)
- **Date**: March 3, 2026
- **Plugin**: ws-coding-workflows
- **Repo**: github.com/Wondersauce/claude-code-plugin
- **Status**: Living Document

---

## 1. Problem Statement

Claude Code is effective at project start. As complexity grows, five failure modes emerge:

1. **Architectural drift** — Claude loses awareness of established patterns and invents alternatives
2. **Code duplication** — Without a map of what exists, Claude re-implements utilities
3. **CSS/styling entropy** — `!important` overrides accumulate, design tokens get bypassed
4. **Inconsistent cross-module integration** — Different modules call each other through different patterns
5. **Context loss between sessions** — Decisions live in chat history, not structured form

The existing ws-codebase-documenter skill produces high-quality descriptive documentation — it thoroughly documents what the system *is*. But it doesn't tell an AI agent how to *work within* the system. When Claude Code needs to add a new endpoint, create a new component, or touch frontend styles, it falls back on inference — which produces inconsistent results.

## 2. Objective

Build a five-layer framework addressing each root cause:

| Layer | What It Does | Implemented By |
|-------|-------------|----------------|
| Project Constitution | Primes agent with context, rules, conventions before every task | `CLAUDE.md` + `documentation/` via ws-codebase-documenter |
| Sub-Agent Architecture | Routes work to specialists with bounded, focused context | ws-orchestrator via `Task()` delegation |
| Documentation-as-You-Build | Reads docs before building, updates after completing | ws-dev read step + ws-codebase-documenter update step |
| Refactoring Checkpoints | Periodic consistency audits; catch drift before it compounds | ws-verifier + ws-codebase-documenter incremental scan |
| Guardrails and Validation | Automated checks at every build cycle | ws-verifier findings driving iteration |

Additionally, extend ws-codebase-documenter to generate **prescriptive documentation** alongside the existing descriptive documentation — documents that an AI coding agent can use as enforceable rules and step-by-step playbooks. The incremental mode gains the ability to detect when new code deviates from established patterns and flag it.

## 3. Scope

### In Scope

**Orchestration Framework:**
- ws-orchestrator — development lifecycle orchestrator
- ws-planner — structured task decomposition from project documentation
- ws-dev — pattern-locked implementation with frontend/backend/fullstack support
- ws-verifier — independent output verification against task definitions and conventions
- Shared infrastructure: session persistence, context isolation, structured result contracts

**Documentation Enhancement (ws-codebase-documenter v2.0):**
- New document types: Development Playbook, Capability Map, Style Guide, Cross-Module Integration Map
- Enhanced CLAUDE.md injection with project-specific rules
- Enhanced config.json with additional configurable fields
- Frontend-aware scanning (CSS/SCSS, JS initialization patterns, design tokens)
- Consistency checking in incremental mode
- Updated doc-templates.md with new templates
- All existing stacks (Node.js, Python, Go, Rust, .NET, Java, PHP)

### Out of Scope

- Changes to Docusaurus sync (works as-is; new doc types sync automatically via existing mechanism)
- New stack detection (no new languages)
- UI or web interface
- Real-time/watch-mode documentation updates

---

## 4. Architecture Overview

```
┌──────────────────────────────────────────────────────┐
│                    ws-orchestrator                     │
│           (Main context — orchestrator only)          │
│                                                      │
│   Reads: CLAUDE.md, .ws-session/orchestrator.json    │
│   Writes: .ws-session/orchestrator.json              │
│   Never touches: code, documentation, implementation │
└───────────┬──────────────────────────────────────────┘
            │  Task() calls — each gets isolated context
            │
   ┌────────┴──────────────────────────────┐
   ▼                  ▼                    ▼
ws-planner         ws-dev             ws-verifier
               frontend/ | backend/
```

After verification passes, ws-orchestrator invokes ws-codebase-documenter to update project documentation.

**Lifecycle:** `plan → build → verify → document`

1. **Plan** — `Task(ws-planner)` produces structured Task Definitions
2. **Build** — `Task(ws-dev)` implements tasks in dependency order
3. **Verify** — `Task(ws-verifier)` independently reviews output
4. **Document** — `Task(ws-codebase-documenter)` updates project docs

---

## 5. Shared Infrastructure

All orchestration skills share these conventions.

### 5.1 Session State Persistence

Every skill maintains its own state file under `.ws-session/`:

```
.ws-session/
├── orchestrator.json       # ws-orchestrator state
├── planner.json            # ws-planner state
├── dev.json                # ws-dev state
├── verifier.json           # ws-verifier state
└── archive/                # completed sessions
```

**Note:** ws-codebase-documenter maintains its own state at `documentation/.docstate` and `documentation/config.json` rather than `.ws-session/`. This is a recognized equivalence — do not create or reference a `documenter.json` file under `.ws-session/`.

State file rules:
- Written atomically after **every** state transition
- Always update `updated_at` on each write
- Never deleted by the creating skill — ws-orchestrator manages archival
- Must be valid, human-readable JSON at all times
- Status enum: `active | paused | complete | blocked | failed` (with skill-specific additions)

**Fullstack session file ownership:** When ws-dev executes a `fullstack` task, it splits into nested `Task()` calls for frontend and backend with `nested: true`. The parent ws-dev instance owns `dev.json`. Nested calls skip all session file operations (Step 0, state updates) and return structured results to the parent, which records both results in `dev.json`. The `nested: true` flag is what prevents file contention — without it, nested calls would attempt to read/write `dev.json` concurrently with the parent.

### 5.2 Context Window Isolation

- ws-orchestrator context stays shallow — session state, routing, result evaluation only
- Each `Task()` starts with a clean context, loads only what it needs, returns a structured result
- The main context never accumulates code, diffs, or documentation content
- Compaction loses nothing of substance — the state file has everything

### 5.3 Structured Result Format

All skills return results in this base contract:

```json
{
  "skill": "skill-name",
  "session_id": "uuid-v4",
  "status": "success | partial | failed",
  "summary": "one-line human-readable outcome",
  "outputs": {},
  "issues": [],
  "next_action": "recommended next step for orchestrator"
}
```

**Status vocabulary exception:** ws-verifier uses `pass | partial | fail` instead of `success | partial | failed`. This is a deliberate domain-specific override — verification results are judgments, not task outcomes. ws-orchestrator's Step 5 expects this vocabulary from ws-verifier specifically.

**Additional status — `blocked`:** ws-dev may return `status: "blocked"` when an uncovered architectural issue prevents implementation. This triggers re-planning rather than iteration.

### 5.4 Documentation Dependency

All implementation skills read project documentation before doing work:

| Priority | Document | Purpose |
|----------|----------|---------|
| **Critical** | `documentation/playbook.md` | How to build things correctly |
| **Critical** | `documentation/capability-map.md` | What already exists |
| Required | `documentation/overview.md` | Project structure, stack |
| Required | `documentation/architecture.md` | Module boundaries, data flow |
| Conditional | `documentation/style-guide.md` | Frontend conventions (if frontend tasks) |
| Conditional | `documentation/integration-map.md` | Cross-module patterns (if cross-module tasks) |

If `playbook.md` or `capability-map.md` is missing, skills hard-fail and return immediately with `next_action: "Run ws-codebase-documenter in bootstrap mode"`.

### 5.5 Drift Detection

Every skill includes a Drift Detection section as a standard component. This is a set of "if you find yourself about to X, STOP" instructions that trigger when the agent is about to violate its role boundaries:

- **ws-orchestrator:** Drifts if it reads source code, writes code, or makes implementation decisions
- **ws-planner:** Drifts if it writes code, runs tests, or guesses at undocumented patterns
- **ws-dev:** Drifts if it makes architectural decisions, skips documentation, or re-implements existing capabilities
- **ws-verifier:** Drifts if it writes code, fixes issues, or lowers severity ratings without justification

When drift is detected, the skill re-reads its Identity section and either corrects course or returns `status: "blocked"` with the issue described.

### 5.6 Compaction Recovery

Every skill includes a Step 0 that checks for an active session file before doing anything else. If found, it resumes from where it left off. Sessions survive compaction, crashes, and restarts.

---

## 6. Skill Specifications

### 6.1 ws-orchestrator

The default operating mode for Claude Code sessions. Never writes code, never modifies documentation, never performs implementation. Routes work to sub-skills, manages session state, evaluates results, drives the lifecycle.

#### 6.1.1 Boot Sequence

1. **Session recovery** (Step 0) — check for active session in `.ws-session/orchestrator.json`
2. **Environment validation** (Step 1) — verify `.ws-session/` dir, check for `documentation/`, detect project name
3. **Sub-skill verification** (Step 1.4) — verify that `ws-planner`, `ws-dev`, `ws-verifier`, and `ws-codebase-documenter` are all installed. Hard-fail if any are missing. Do not attempt to do the missing skill's work inline.
4. **Check CLAUDE.md boot block** (Step 1.5) — check for the marker `## WS AI Master Plan — Session Boot`
5. **Receive task** (Step 2) — accept and classify task, check if docs need bootstrapping, offer boot block injection if not installed

When called with no argument and the boot block is not installed, ws-orchestrator offers to inject it before prompting for a task.

#### 6.1.2 Lifecycle

```
plan → build → verify → document
```

- **Plan** (Step 3) — `Task(ws-planner)` produces structured Task Definitions. User reviews and approves.
- **Build** (Step 4) — `Task(ws-dev/[area])` implements tasks in dependency order.
- **Verify** (Step 5) — `Task(ws-verifier)` independently reviews output.
- **Document** (Step 6) — `Task(ws-codebase-documenter)` with `skip_pr: true` updates project docs without creating a PR. Archive session.

**Iteration loop:** If ws-verifier returns `fail` or `partial`, ws-orchestrator maps findings to tasks by matching each finding's `file` field against each task's `files_to_create` and `files_to_modify` arrays, then re-sends **only the tasks with associated findings** back to ws-dev (up to 3 iterations by default). Tasks that passed verification are not re-run. If convergence fails, findings are presented to the user for decision.

#### 6.1.3 Manual Override ([DIRECT])

Prefix any message with `[DIRECT]` to bypass orchestration for informational queries:

```
[DIRECT] What does UserService.findById return?
```

**Read-only constraint:** `[DIRECT]` mode is strictly read-only. Any request that would result in code changes is rejected back into the full lifecycle regardless of the `[DIRECT]` prefix.

#### 6.1.4 Error Handling

**Sub-skill invocation failure:** If a `Task()` call fails, log the error and present retry/skip/abort options to the user.

**Session file corruption:** If `.ws-session/orchestrator.json` cannot be parsed:
1. Rename corrupted file to `.ws-session/orchestrator.json.corrupted.[timestamp]`
2. Ask user to describe the current task state
3. Initialize a new session

This ensures no data is silently lost — the corrupted file is preserved for debugging.

### 6.2 ws-planner

Given a task description and project documentation, produces fully specified, structured development plans. Determines what to build, how to structure it per existing patterns, how to decompose into sub-tasks, and what constraints apply.

#### Task Definition Format

Each sub-task includes: task_id, title, type, area, description, acceptance_criteria, constraints, files_to_create, files_to_modify, documentation_updates, depends_on, estimated_complexity, playbook_procedure, reuse (with exact import paths).

#### Key Behaviors

- Hard-fails if `playbook.md` or `capability-map.md` is missing
- Never guesses at patterns not in the documentation
- Every acceptance criterion must be testable and verifiable by ws-verifier
- Every file modification references a specific playbook procedure
- No open architectural decisions left for ws-dev
- **Blocking ambiguities stop planning immediately** — if the task is too ambiguous to decompose (indeterminate area, contradictory constraints, undefined core requirements), ws-planner returns `status: "partial"` with zero tasks and the ambiguities listed, rather than propagating bad assumptions through decomposition. Non-blocking ambiguities (minor naming, placement preferences) are recorded but don't halt planning.

#### Re-planning with Feedback

When ws-orchestrator re-invokes ws-planner with user feedback, it passes a `feedback` parameter. This signals ws-planner's Step 0 to enter re-planning mode instead of initializing a fresh session (which would wipe the previous plan):

1. Step 0 detects `feedback` parameter and reads the existing `complete` session instead of initializing fresh
2. Apply adjustments: add/remove/modify tasks, adjust criteria, change granularity, address ambiguities
3. Re-run validation
4. Return updated result with history recorded in the `notes` field

### 6.3 ws-dev

Implements fully-specified tasks from ws-planner. Reads documentation before writing any code, follows exact patterns from the task definition, reuses identified existing capabilities. Does not make architectural decisions.

#### Sub-skills

| Sub-skill | Area |
|-----------|------|
| **ws-dev/frontend** | UI components, styling, client-side logic, accessibility |
| **ws-dev/backend** | API endpoints, data models, services, business logic |
| **ws-dev/fullstack** | Tasks spanning both — splits into frontend/backend and delegates via nested `Task()` calls |

#### Fullstack Orchestration

For fullstack tasks, ws-dev splits work into backend-first execution (frontend depends on API contracts), then merges results. Nested calls are invoked with `nested: true`, which tells the sub-skill to skip all session file operations. The parent ws-dev instance owns `dev.json`; nested calls return results only.

If the task cannot be cleanly split, ws-dev executes the entire task directly using combined conventions from both frontend and backend layers.

#### Architectural Blocking

If implementation reveals an uncovered architectural issue, ws-dev **stops immediately** and returns `status: "blocked"` with the decision needed. It never makes architectural decisions on its own.

#### Frontend Conventions Layer

Non-negotiable rules for all frontend implementation:
- Always read `style-guide.md` before writing CSS — blocks if missing
- Never use `!important` except documented overrides
- Never hard-code design token values
- All interactive elements must have ARIA labels
- All images must have alt text
- All components must respect documented responsive breakpoints

#### Backend Conventions Layer

Non-negotiable rules for all backend implementation:
- Use established data access pattern (service/repository)
- Never bypass auth middleware
- Use documented error handling — no raw exceptions in API responses
- All endpoints follow documented request/response envelope format
- Schema changes require migration files
- External service calls through established service layer

### 6.4 ws-verifier

Independently reviews ws-dev output against the task definition, project documentation, and coding conventions. Reads, analyzes, and judges — never re-implements.

#### Verification Domains

1. **Acceptance criteria** — is each criterion met?
2. **Pattern compliance** — does implementation follow the playbook?
3. **Reuse compliance** — were existing capabilities used, not re-implemented?
4. **Constraint compliance** — are all constraints respected?
5. **Documentation currency** — does output require doc updates beyond what's planned?

#### Finding Severity Levels

| Severity | Definition | Examples |
|----------|-----------|---------|
| **HIGH** | Architectural violation, security bypass, or constraint violation | Direct DB call bypassing service; `!important`; re-implemented existing utility; auth middleware bypassed |
| **MEDIUM** | Pattern deviation creating inconsistency | Wrong error format; missing ARIA; inconsistent naming; undocumented public API |
| **LOW** | Minor, doesn't violate conventions | Unused import; inconsistent spacing; import from non-canonical path |

#### Pass/Fail Thresholds

| Result | Condition |
|--------|-----------|
| `pass` | Zero HIGH findings AND >80% criteria met |
| `partial` | Some criteria met, some findings, but does not meet `fail` threshold |
| `fail` | Any HIGH finding OR <50% criteria met |

**Status vocabulary:** ws-verifier uses `pass`/`partial`/`fail` instead of the base contract's `success`/`partial`/`failed`. This is a deliberate domain-specific override — verification results are judgments, not task outcomes.

### 6.5 ws-codebase-documenter

Scans the codebase and generates structured documentation optimized for AI consumption. Produces both descriptive docs (what code does) and prescriptive docs (how to build new things correctly). See Sections 7–15 for the full documentation generation specification.

**State location:** Uses `documentation/.docstate` and `documentation/config.json` for state tracking, not `.ws-session/documenter.json`.

---

## 7. New Document Types

### 7.1 Development Playbook

**Path**: `documentation/playbook.md`

**Purpose**: Step-by-step instructions for common development tasks within this specific codebase. This is the primary document that prevents architectural drift.

**Content** (generated by analyzing detected patterns during scan):

- **How to Add a New REST Endpoint**: Detected from Router/Controller/Handler patterns. Step-by-step including which directory to create files in, which base class or pattern to follow, how to register the route, what validation pattern to use, and what response format to return.
- **How to Add a New Data Model**: Detected from existing Model classes. Includes which directory, what base class or pattern, what methods are expected (e.g., `get_by`, `where`, `save`, `to_array`), what caching pattern to use, and what database table naming convention to follow.
- **How to Add a New UI Component/Block**: Detected from existing component/block structure. Includes template file location, stylesheet location, JS entry point location, naming conventions, and registration pattern.
- **How to Add a New Helper/Utility Function**: Detected from existing helper locations and patterns. Includes where helpers live, naming conventions, and when to create a new helper vs extend an existing one.
- **How to Add a New Service/Integration**: Detected from existing service patterns. Includes the initialization pattern, dependency injection or instantiation approach, and configuration management pattern.
- **How to Handle Errors**: Detected from existing error handling patterns. Includes the project's error class hierarchy, standard error response format, and how to create new error types.
- **How to Add Tests**: Detected from test directory structure and patterns if they exist.

**Generation Logic**:

1. During the codebase scan (step 2.4), when patterns are detected for the architecture.md design patterns table, also extract the concrete file paths, base classes, method signatures, and directory conventions that form each pattern.
2. For each detected pattern, generate a numbered step-by-step procedure that a developer (human or AI) can follow to create a new instance of that pattern.
3. Include a "Checklist" at the end of each procedure: a bulleted list of things to verify after completing the steps (e.g., "Route is registered in Router", "Model has `save()` and `to_array()` methods", "SCSS file is imported in main stylesheet").
4. Include a "Common Mistakes" subsection for each procedure listing anti-patterns detected in the codebase (e.g., if the scan finds any direct database queries outside of Model classes, note "Do NOT query the database directly—always use Model static methods").

**Template**: See Section 12.1.

### 7.2 Capability Map

**Path**: `documentation/capability-map.md`

**Purpose**: Task-oriented lookup that answers "I need to do X—what should I use?" Organized by what a developer is trying to accomplish, not by module or file structure. This is the primary document that prevents code duplication.

**Content** (generated by clustering public and key private API by functional domain):

Each section represents a task category. Under each category, list every relevant function, class, helper, or pattern with a one-line description and a link to its full documentation.

**Categories to detect and generate** (non-exhaustive—the skill should detect what's relevant for each project):

- Authentication & Session Management
- Authorization & Access Control
- Data Retrieval & Querying
- Data Persistence & Mutations
- Payment Processing
- Email & Notifications
- Content Management
- Caching
- Validation & Sanitization
- Error Handling
- File & Media Handling
- Search
- External API Integration
- Logging & Tracking
- Configuration & Settings
- Frontend Utilities (JS helpers, DOM manipulation)
- Styling Utilities (mixins, design tokens, utility classes)

**Generation Logic**:

1. After the full scan produces the public and private API inventories, run a second classification pass.
2. For each documented function/type/class, determine its functional domain based on: the module/namespace it belongs to, its name, its parameters and return types, and its doc comment/description.
3. Group items by functional domain. A single item can appear in multiple categories if it serves multiple purposes (e.g., a `User` model might appear under both "Authentication" and "Data Retrieval").
4. Within each category, order items by likelihood of use (most commonly needed first). Use heuristics: functions referenced by more other functions rank higher; simpler/more general functions rank above specialized ones.
5. For each item in the map, include: the function/type name, a one-line description, the import/require path or namespace, and a link to the full doc file.
6. Include a "Before You Create Something New" callout at the top of the document instructing the reader to search this map before implementing any new functionality.

**Template**: See Section 12.2.

### 7.3 Style Guide

**Path**: `documentation/style-guide.md`

**Purpose**: Documents frontend conventions including CSS/SCSS methodology, design tokens, responsive patterns, JS component initialization, and asset organization. This is the primary document that prevents CSS entropy and frontend inconsistency.

**Content** (generated by scanning frontend assets):

- **CSS/SCSS Methodology**: Detected from file organization and naming patterns. Is BEM used? SMACSS? Utility-first? Component-scoped? Document what's detected and prescribe it as the rule.
- **File Organization**: Map of where stylesheets live, how they're organized (by block, by component, by page), and the import/inclusion chain (main entry SCSS file and its imports).
- **Design Tokens**: If a tokens file, variables file, or CSS custom properties root exists, document all available tokens with their values. Categories: colors, spacing, typography (font families, sizes, weights, line heights), breakpoints, shadows, border radii, z-index scale.
- **Responsive Breakpoints**: Detected from media queries or breakpoint variables. Document each breakpoint, its value, and the convention (mobile-first vs desktop-first).
- **Component Styling Pattern**: How styles are applied to components/blocks. Is there one SCSS file per block? Per component? How is it named relative to the component? How is it imported?
- **Naming Conventions**: CSS class naming patterns detected from the codebase (e.g., `.block-name`, `.block-name__element`, `.block-name--modifier`).
- **Forbidden Patterns**: Detected anti-patterns. If `!important` is found, count occurrences and note it as a pattern to avoid. If inline styles are found in templates, flag them. If styles are duplicated across files, note the duplication.
- **JS Component Initialization**: How JS components are loaded and initialized. Detect the pattern (DOMReady callbacks, React hydration, module init functions) and document it as the convention.
- **JS Entry Points**: Map of JS entry point files, what they initialize, and their dependencies.
- **Asset Build Pipeline**: If a build tool config is detected (webpack, vite, gulp, etc.), document the build commands and asset output locations.

**Generation Logic**:

1. Scan for CSS/SCSS/LESS files outside of `node_modules`, `vendor`, `dist`, `build` directories.
2. Parse SCSS/CSS files for: variable declarations (`$var` or `--custom-property`), media query breakpoints, class naming patterns (regex for BEM, utility classes, etc.), `!important` usage count, import chains.
3. Scan for JS/TS files that match initialization patterns: files importing and calling `.init()`, files with `DOMContentLoaded` or `DOMReady` listeners, files with `ReactDOM.render` or `createRoot`, files matching `src/js/blocks/*` or similar patterns.
4. If a design token file is detected (common names: `_variables.scss`, `_tokens.scss`, `tokens.ts`, `tokens.json`, `theme.ts`), parse it fully and include all token values in the doc.
5. Generate prescriptive rules from detected patterns. For example: if all existing SCSS files follow a `src/css/blocks/[block-name].scss` pattern, generate the rule "New block styles MUST be created at `src/css/blocks/[block-name].scss`."

**Stack-Specific Frontend Detection**:

| Stack | Frontend Indicators |
|-------|-------------------|
| PHP (WordPress) | `src/css/`, `src/js/`, `webpack.config.js`, `gulpfile.js`, `package.json` scripts |
| Node.js (Next.js) | `styles/`, `app/**/*.module.css`, `tailwind.config.*`, `postcss.config.*` |
| Node.js (React) | `src/styles/`, `src/components/**/*.css`, `styled-components`, `emotion` |
| Python (Django) | `static/css/`, `static/js/` |
| .NET (Blazor/Razor) | `wwwroot/css/`, `wwwroot/js/` |

**Template**: See Section 12.3.

### 7.4 Cross-Module Integration Map

**Path**: `documentation/integration-map.md`

**Purpose**: Documents how modules communicate with each other—what functions/services in Module A are called by Module B, and in what context. This prevents inconsistent cross-module integration patterns when building features that span boundaries.

**Content**:

- **Module Dependency Matrix**: A table showing which modules depend on which other modules and through what interface (function call, event, shared database table, API call).
- **Integration Patterns**: For each module pair that interacts, document the specific pattern: which functions are called, in what order, what data is passed, and what the expected return/behavior is.
- **Shared Resources**: Database tables, cache keys, global variables, or configuration values that are accessed by multiple modules.
- **Event/Hook Contracts**: If the system uses events, hooks, signals, or pub/sub patterns (very common in WordPress, Django, .NET), document what events each module emits and what events each module listens to.

**Generation Logic**:

1. During the codebase scan, track cross-namespace/cross-module function calls. When code in namespace `A` calls a function from namespace `B`, record that relationship.
2. For WordPress specifically: scan for `add_action`, `add_filter`, `do_action`, `apply_filters` calls. Map which module registers each hook and which module fires each hook.
3. For each detected cross-module call, record: the calling module, the called function/method, the file and line where the call occurs, and any data passed.
4. Group these into integration patterns: "Module A calls Module B's function X when doing Y."
5. Generate the dependency matrix from the aggregated call data.
6. Identify shared database tables by checking which modules reference the same table names.

**Template**: See Section 12.4.

---

## 8. Enhanced CLAUDE.md Injection

### 8.1 Documentation Rules Injection

**Owner**: ws-codebase-documenter (during bootstrap and incremental updates)

After generating all documentation (including new doc types), extract project-specific rules and inject them into CLAUDE.md as explicit "Project Rules" and "Codebase Documentation" sections. These sections are generated, not boilerplate.

**Rule Extraction Logic**:

1. From `playbook.md`: Extract the key "do this, not that" items from each procedure. Condense into short imperative rules.
2. From `capability-map.md`: Generate a rule that says "Before creating any new utility function, helper, or shared component, check `documentation/capability-map.md` to verify it doesn't already exist."
3. From `style-guide.md`: Extract the top 5-10 most important frontend rules (no `!important`, use design tokens, follow naming convention, etc.).
4. From `architecture.md`: Extract the core patterns (e.g., "all REST endpoints follow Router → Controller → Model pattern").
5. From `integration-map.md`: Extract rules about how to properly call across module boundaries.

The number of rules injected should be kept to a maximum of 25 total to avoid bloating CLAUDE.md.

### 8.2 Orchestrator Boot Block

**Owner**: ws-orchestrator (NOT ws-codebase-documenter)

The orchestrator boot block is injected by ws-orchestrator itself, not by ws-codebase-documenter. This is a deliberate design choice: the user explicitly activates orchestration as a separate step from documentation generation. A first-time user runs ws-codebase-documenter to generate docs, then invokes ws-orchestrator to activate the full lifecycle.

When ws-orchestrator is called with no argument and the boot block is not yet installed, it offers to inject the auto-activation block into `CLAUDE.md`. The block is identified by the marker `## WS AI Master Plan — Session Boot` and includes:

- Orchestrator activation instructions
- Identity declaration ("You are operating as ws-orchestrator")
- Context recovery instructions (read `.ws-session/orchestrator.json`)
- Manual override reference (`[DIRECT]` prefix)

The injection is idempotent — the marker check prevents duplicate injection.

### 8.3 CLAUDE.md Injection Templates

**Documentation injection template** (ws-codebase-documenter):

```markdown
## Project Rules

These rules MUST be followed when modifying this codebase:

### Architecture
- [Generated rules from architecture.md and playbook.md]

### Data Access
- [Generated rules about ORM/Model usage patterns]

### Frontend
- [Generated rules from style-guide.md]

### Before Creating New Code
- Check `documentation/capability-map.md` before creating any new utility, helper, or shared function
- Check `documentation/public/_index.md` before creating any new public API
- Follow the step-by-step procedures in `documentation/playbook.md` for common tasks

### Documentation
- After adding new public functions, types, or components, update the relevant documentation files
- After adding new cross-module integrations, update `documentation/integration-map.md`

## Codebase Documentation

This project has AI-optimized documentation in the `documentation/` folder.

Before making changes to this codebase:
1. Read `documentation/overview.md` for project purpose and entry points
2. Read `documentation/architecture.md` for system design and data flow
3. Read `documentation/playbook.md` for how to add new features
4. Check `documentation/capability-map.md` for existing utilities and helpers
5. Check `documentation/style-guide.md` for frontend conventions
6. Check `documentation/public/_index.md` for the public API surface

When modifying existing code:
- Check the relevant function/type doc in `documentation/public/` or `documentation/private/`
- Note any error handling patterns in `documentation/public/errors/`

When adding new public APIs:
- Follow patterns documented in `documentation/playbook.md`
- Ensure consistency with existing APIs in `documentation/public/`
- Update `documentation/capability-map.md` with the new capability
```

---

## 9. Enhanced config.json

### Current Fields (Preserve)

- `stack`
- `exclude`
- `include_inline_examples`
- `include_architecture_diagrams`
- `docusaurus`

### New Fields (Add)

```json
{
  "stack": "php",
  "exclude": ["..."],
  "include_inline_examples": true,
  "include_architecture_diagrams": true,
  "docusaurus": null,

  "frontend": {
    "enabled": true,
    "css_paths": ["src/css/", "src/scss/", "styles/"],
    "js_paths": ["src/js/", "src/ts/"],
    "token_files": [],
    "build_tool": null,
    "methodology": null
  },

  "playbook": {
    "enabled": true,
    "custom_procedures": []
  },

  "capability_map": {
    "enabled": true,
    "custom_categories": []
  },

  "style_guide": {
    "enabled": true,
    "forbidden_patterns": ["!important", "inline styles"],
    "custom_rules": []
  },

  "integration_map": {
    "enabled": true
  },

  "consistency_check": {
    "enabled": true,
    "strict": false
  },

  "claude_md": {
    "inject_rules": true,
    "max_rules": 25,
    "custom_rules": []
  }
}
```

**Field Descriptions**:

- `frontend.enabled`: Whether to scan for and generate frontend documentation. Default `true`. Set to `false` for pure backend/library projects.
- `frontend.css_paths`: Directories to scan for CSS/SCSS/LESS files. Auto-detected if empty.
- `frontend.js_paths`: Directories to scan for JS/TS frontend files. Auto-detected if empty.
- `frontend.token_files`: Explicit paths to design token files. Auto-detected if empty.
- `frontend.build_tool`: Build tool in use (`webpack`, `vite`, `gulp`, `rollup`, `esbuild`, `none`). Auto-detected if null.
- `frontend.methodology`: CSS methodology (`bem`, `smacss`, `utility`, `module`, `none`). Auto-detected if null; detection can be overridden by setting explicitly.
- `playbook.enabled`: Whether to generate playbook.md. Default `true`.
- `playbook.custom_procedures`: Array of additional procedure titles the user wants documented (the skill will attempt to detect the pattern and generate the procedure, or create a placeholder if undetectable).
- `capability_map.enabled`: Whether to generate capability-map.md. Default `true`.
- `capability_map.custom_categories`: Additional task categories to include beyond auto-detected ones.
- `style_guide.enabled`: Whether to generate style-guide.md. Default `true`.
- `style_guide.forbidden_patterns`: Patterns to flag as anti-patterns in generated documentation. Default includes `!important` and inline styles.
- `style_guide.custom_rules`: Additional rules to include verbatim in the generated style guide.
- `integration_map.enabled`: Whether to generate integration-map.md. Default `true`.
- `consistency_check.enabled`: Whether incremental mode runs consistency checks. Default `true`.
- `consistency_check.strict`: If `true`, consistency violations are listed as errors in the PR description. If `false`, listed as warnings. Default `false`.
- `claude_md.inject_rules`: Whether to inject project-specific rules into CLAUDE.md. Default `true`.
- `claude_md.max_rules`: Maximum number of rules to inject. Default `25`.
- `claude_md.custom_rules`: Additional rules to inject verbatim (e.g., project-specific rules that can't be auto-detected).

**Bootstrap Behavior Change**: During step 2.2 (Create Config), include the new fields with their defaults. Auto-detection populates `frontend.*` fields after the initial scan; the config is written a second time after detection completes with the detected values filled in so the user can review and override them.

---

## 10. Consistency Checking (Incremental Mode Enhancement)

### Current Incremental Behavior (Preserve)

Steps 3.1–3.6 remain unchanged: load state, get changes, analyze changes, update documentation, verify CLAUDE.md, update state.

### New Step: 3.4.5 — Consistency Check

Insert after step 3.4 (Update Documentation) and before step 3.5 (Verify Claude Code Instructions).

**When**: Only when `config.consistency_check.enabled` is `true`.

**Logic**:

1. Load the current `playbook.md`, `architecture.md`, `style-guide.md`, and `integration-map.md`.
2. For each file that was changed (from step 3.2), check for the following violations:

**Architectural Violations**:
- New REST endpoint/route that doesn't follow the detected Router → Controller → Model (or equivalent) pattern
- New data access code that bypasses the established Model/Repository pattern (direct database queries where Models are the convention)
- New module/package that doesn't follow the established directory structure convention
- New class/function that duplicates functionality already documented in `capability-map.md` (fuzzy match on name and purpose)

**Frontend Violations** (when `style_guide.enabled` is `true`):
- New CSS/SCSS files that don't follow the established naming or location conventions
- Use of `!important` (or other patterns in `style_guide.forbidden_patterns`)
- Inline styles in template files
- New JS files that don't follow the established initialization pattern
- Use of hard-coded values where design tokens exist for the same purpose (e.g., a color hex value that matches a token)

**Integration Violations**:
- Cross-module calls that don't use the established interface (e.g., reaching into a module's internals instead of using its public API)
- New shared database table access without updating integration-map.md

3. For each detected violation, record: the file path, the line number or code block, the rule that was violated, and a suggested fix.

4. If any violations are found, generate a `documentation/.consistency-report.md` file with the findings. This file is included in the commit and referenced in the PR description.

**PR Description Enhancement**:

Add a new section to the PR template:

```markdown
### Consistency Check

**Status**: [PASS | X warnings | X errors]

#### Violations Found

| File | Line | Rule | Severity | Description |
|------|------|------|----------|-------------|
| `path/to/file.php` | 42 | Data access pattern | Warning | Direct database query; should use Model::get_by() |
| `src/css/new-block.scss` | 15 | No !important | Warning | !important used on line 15 |

#### Suggestions

- `path/to/file.php:42` — Replace `$wpdb->get_results(...)` with `Purchase::where([...])` per the data access pattern in `documentation/playbook.md`
```

**Severity Levels**:
- `Error` (only when `consistency_check.strict` is `true`): Pattern that directly contradicts a documented rule
- `Warning`: Pattern that deviates from convention but may be intentional

---

## 11. Updated Workflow

The SKILL.md workflow is updated as follows. All existing steps are preserved; new steps and modifications are marked with `[NEW]` or `[MODIFIED]`.

### Bootstrap Mode Updates

**Step 2.4 [MODIFIED] — Scan Codebase**:

Add to existing scan:

5b. Scan frontend assets (CSS/SCSS/LESS/JS/TS) if `config.frontend.enabled` is `true`. Detect: file organization, naming conventions, variable/token declarations, media query breakpoints, `!important` count, import chains, JS initialization patterns, build tool configuration.

5c. Track cross-module function calls and shared resource access for integration map generation.

5d. For each detected design pattern, extract the concrete file paths, base classes, directory conventions, and method signatures that define the pattern (used for playbook generation).

**Step 2.5 [MODIFIED] — Generate Documentation**:

Add to directory structure:

```
documentation/
├── config.json
├── .docstate
├── overview.md
├── architecture.md
├── playbook.md                    [NEW]
├── capability-map.md              [NEW]
├── style-guide.md                 [NEW]
├── integration-map.md             [NEW]
├── public/
│   ├── _index.md
│   ├── features/
│   ├── api/
│   ├── functions/
│   ├── types/
│   └── errors/
└── private/
    ├── _index.md
    ├── functions/
    ├── types/
    └── utils/
```

Add to file generation list:

7. `playbook.md` — Development procedures generated from detected patterns (Section 7.1)
8. `capability-map.md` — Task-oriented API lookup (Section 7.2)
9. `style-guide.md` — Frontend conventions and rules (Section 7.3)
10. `integration-map.md` — Cross-module communication patterns (Section 7.4)

**Step 2.6 [MODIFIED] — Update Claude Code Instructions**:

Replace the boilerplate CLAUDE.md injection with the enhanced version from Section 8.1. Extract project-specific rules from generated documentation and inject them.

### Incremental Mode Updates

**Step 3.4 [MODIFIED] — Update Documentation**:

Add to the "Also update" list:

- `playbook.md` if new patterns are detected or existing patterns change
- `capability-map.md` if new public functions/types/helpers are added
- `style-guide.md` if new frontend files introduce different conventions or new tokens
- `integration-map.md` if new cross-module calls are detected

**Step 3.4.5 [NEW] — Consistency Check**:

Run consistency checking as described in Section 10.

**Step 3.5 [MODIFIED] — Verify Claude Code Instructions**:

In addition to checking that the documentation reference section exists, verify that the rules section exists and is current. If rules have changed (because the underlying documentation changed), update the rules in CLAUDE.md.

---

## 12. New Templates

Add the following to `references/doc-templates.md`.

### 12.1 Development Playbook Template

```markdown
# Development Playbook

> Step-by-step procedures for common development tasks in this project.
> Follow these procedures to maintain architectural consistency.

## Before You Start

Before adding any new functionality:
1. Check `capability-map.md` to see if similar functionality exists
2. Read `architecture.md` to understand the system structure
3. Follow the appropriate procedure below

## Adding a New [Pattern Name]

### When to Use
[Description of when this procedure applies]

### Steps

1. [Concrete step with file paths and naming conventions]
2. [Next step]
3. [Next step]

### Template

```[language]
[Boilerplate code that follows the pattern]
```

### Checklist

- [ ] [Verification item]
- [ ] [Verification item]
- [ ] Documentation updated

### Common Mistakes

- **Don't**: [Anti-pattern description]
  **Do**: [Correct approach]

---

[Repeat for each detected pattern]
```

### 12.2 Capability Map Template

```markdown
# Capability Map

> Find existing functionality before creating something new.

**IMPORTANT**: Before implementing any new utility, helper, or shared
function, search this document to check if it already exists.

## [Category Name]

[One-line description of this category]

| Capability | Function/Type | Module | Import/Path |
|------------|--------------|--------|-------------|
| [What it does] | [`functionName()`](link) | ModuleName | `Namespace\Class` |

---

[Repeat for each category]
```

### 12.3 Style Guide Template

```markdown
# Style Guide

> Frontend conventions and rules for this project.

## CSS Methodology

**Approach**: [Detected methodology]

### File Organization

| Type | Location | Naming |
|------|----------|--------|
| [Block/Component styles] | [path] | [convention] |

### Naming Conventions

[Detected class naming pattern with examples]

## Design Tokens

### Colors

| Token | Value | Usage |
|-------|-------|-------|
| `$token-name` | `#value` | [Where it's used] |

### Spacing

| Token | Value |
|-------|-------|
| `$token-name` | `value` |

### Typography

| Token | Value |
|-------|-------|
| `$font-family-name` | `value` |

### Breakpoints

| Name | Value | Usage |
|------|-------|-------|
| `$breakpoint-name` | `value` | [mobile-first/desktop-first] |

## JavaScript Patterns

### Component Initialization

[Detected pattern with example]

### Entry Points

| File | Purpose | Dependencies |
|------|---------|-------------|
| [path] | [what it initializes] | [deps] |

## Rules

1. [Generated rule]
2. [Generated rule]

## Forbidden Patterns

| Pattern | Reason | Alternative |
|---------|--------|-------------|
| `!important` | Causes specificity issues | Use more specific selectors or restructure |
| Inline styles | Not maintainable | Use CSS classes |
| [Detected anti-pattern] | [Reason] | [Alternative] |
```

### 12.4 Cross-Module Integration Map Template

```markdown
# Cross-Module Integration Map

> How modules communicate with each other in this project.

## Module Dependency Matrix

| Module | Depends On | Through |
|--------|-----------|---------|
| [Module A] | [Module B] | [`functionName()`](link) |

## Integration Patterns

### [Module A] → [Module B]

**Context**: [When/why Module A calls Module B]

**Pattern**:
```[language]
[Code showing the correct way to make this call]
```

**Data Contract**:
| Passed | Type | Description |
|--------|------|-------------|
| [param] | [type] | [description] |

**Returns**: [What Module B returns to Module A]

## Shared Resources

| Resource | Type | Modules | Notes |
|----------|------|---------|-------|
| [table/cache key/global] | [DB table/Cache/Global] | [List of modules] | [Access pattern] |

## Event/Hook Contracts

| Event/Hook | Emitted By | Listened By | Data |
|-----------|-----------|------------|------|
| [hook name] | [Module] | [Module(s)] | [What data is passed] |
```

---

## 13. New Reference Files

### 13.1 Frontend Detection Reference

**Path**: `references/frontend-detection.md`

This new reference file provides patterns for detecting frontend conventions across stacks. It should contain:

- Common CSS/SCSS variable file names and locations by stack
- Common JS initialization patterns by framework
- Build tool configuration file names and how to parse them for relevant info
- Design token detection heuristics (variable naming patterns like `$color-*`, `--spacing-*`, `$bp-*`)
- CSS methodology detection heuristics:
  - BEM: class names matching `block__element--modifier`
  - Utility-first: high frequency of single-purpose classes, presence of Tailwind config
  - Module/scoped: `.module.css` or `.module.scss` file extensions
  - Component-scoped: styled-components, emotion, CSS-in-JS patterns
- `!important` and anti-pattern detection regex patterns
- Media query breakpoint extraction patterns

### 13.2 Consistency Rules Reference

**Path**: `references/consistency-rules.md`

This new reference file defines the consistency checking rules in a structured format so they can be maintained and extended:

- Rule definitions with: ID, description, severity, detection pattern, suggested fix template
- Stack-specific rule overrides (e.g., WordPress-specific rules for hooks, PHP-specific rules for namespacing)
- How to match new code against documented patterns (fuzzy matching heuristics for detecting duplicated functionality)

---

## 14. Stack Reference Updates

Each stack reference file (`references/stacks/*.md`) needs a new section appended:

### Frontend Indicators Section

Add to each stack file a section titled "## Frontend Indicators" documenting:

- Where frontend assets typically live for projects using this stack
- Common build tool configurations
- How templates/views reference CSS and JS (important for detecting which styles/scripts are actually used)
- Framework-specific frontend patterns (e.g., WordPress `wp_enqueue_script`, Next.js CSS modules, Django `{% static %}`)

### Cross-Module Detection Section

Add to each stack file a section titled "## Cross-Module Patterns" documenting:

- How to detect cross-module/cross-namespace calls in this language
- Event/hook/signal systems common to the stack's frameworks
- Shared resource patterns (database access, configuration, caching)

---

## 15. Updated .docstate

Add new tracking fields to `.docstate`:

```json
{
  "last_commit": "a1b2c3d4...",
  "last_run": "2026-03-03T12:00:00Z",
  "docusaurus_last_sync": null,
  "docusaurus_synced_files": [],
  "consistency_last_check": "2026-03-03T12:00:00Z",
  "consistency_violations": 0,
  "generated_docs": [
    "overview.md",
    "architecture.md",
    "playbook.md",
    "capability-map.md",
    "style-guide.md",
    "integration-map.md"
  ],
  "detected_patterns": {
    "rest_endpoint": "Router → Controller → Model",
    "data_access": "Model static methods with caching",
    "error_handling": "Custom exception hierarchy",
    "frontend_css": "Component SCSS in src/css/blocks/",
    "frontend_js": "Entry points in src/js/blocks/ with .init()",
    "css_methodology": "component-scoped"
  },
  "frontend_stats": {
    "important_count": 0,
    "inline_style_count": 0,
    "token_count": 0,
    "breakpoint_count": 0
  }
}
```

The `detected_patterns` field enables incremental mode to check for consistency without re-running the full pattern detection scan. The `frontend_stats` field enables tracking whether frontend health is improving or degrading between runs.

---

## 16. Implementation Phases

### Phase 1: Orchestration Framework

**Priority**: Highest — provides the structural foundation for all other features.

**Deliverables**:
- `skills/ws-orchestrator/SKILL.md` — lifecycle orchestrator
- `skills/ws-planner/SKILL.md` — task decomposition
- `skills/ws-dev/SKILL.md` — implementation agent (base + frontend + backend)
- `skills/ws-verifier/SKILL.md` — output verification

**Validation**: Invoke ws-orchestrator with a test task. Verify it routes through the full plan → build → verify → document lifecycle with proper session state persistence.

### Phase 2: Playbook + Capability Map

**Priority**: Highest — directly addresses architectural drift and code duplication.

**Files to create/modify**:
- `references/doc-templates.md` — Add playbook and capability map templates
- `SKILL.md` — Update steps 2.4, 2.5, 2.6, 3.4, 3.5

**Validation**: Run bootstrap against the Golf.com WordPress codebase. Verify that `playbook.md` contains procedures for adding REST endpoints, Models, and Gutenberg blocks matching the actual patterns in the codebase. Verify that `capability-map.md` correctly clusters `wsum_*` functions under relevant categories.

### Phase 3: Style Guide + Frontend Scanning

**Priority**: High — directly addresses CSS entropy and frontend inconsistency.

**Files to create/modify**:
- `references/frontend-detection.md` — New file
- `references/doc-templates.md` — Add style guide template
- `references/stacks/php.md` — Add frontend indicators section
- `references/stacks/nodejs.md` — Add frontend indicators section
- `SKILL.md` — Update step 2.4 for frontend scanning

**Validation**: Run bootstrap against the Golf.com codebase. Verify that `style-guide.md` correctly identifies the SCSS file organization, detects design tokens if present, counts `!important` usage, and maps JS entry points.

### Phase 4: Integration Map + Cross-Module Detection

**Priority**: Medium — prevents cross-module integration bugs but less frequently encountered than drift and duplication.

**Files to create/modify**:
- `references/doc-templates.md` — Add integration map template
- `references/stacks/*.md` — Add cross-module detection sections
- `SKILL.md` — Update step 2.4 for cross-module scanning

**Validation**: Run bootstrap against the Golf.com codebase. Verify that `integration-map.md` correctly shows UserManager ↔ StripeConnect ↔ OneTimePayment relationships and documents WordPress hooks/actions used for cross-module communication.

### Phase 5: Consistency Checking

**Priority**: Medium — provides ongoing enforcement but requires Phases 2-4 to have produced accurate documentation to check against.

**Files to create/modify**:
- `references/consistency-rules.md` — New file
- `SKILL.md` — Add step 3.4.5
- `references/doc-templates.md` — Update PR description template

**Validation**: Make an intentional pattern violation in the Golf.com codebase (e.g., add a direct database query where a Model should be used, add `!important` to a stylesheet). Run incremental mode. Verify the consistency report flags the violations.

### Phase 6: Enhanced Config + CLAUDE.md

**Priority**: Medium — improves configurability and rule injection quality.

**Files to create/modify**:
- `SKILL.md` — Update steps 2.2, 2.6, 3.5
- `references/doc-templates.md` — Update config and CLAUDE.md templates

**Validation**: Run bootstrap, verify config.json includes new fields with auto-detected values. Verify CLAUDE.md includes project-specific rules extracted from generated documentation.

---

## 17. Acceptance Criteria

### Orchestration Framework

1. ws-orchestrator routes all implementation work through the plan → build → verify → document lifecycle
2. Each sub-skill runs in an isolated `Task()` context with no shared state beyond session files
3. Session files survive context compaction, crashes, and restarts (Step 0 recovery)
4. ws-orchestrator hard-fails if any required sub-skill is missing
5. Iteration loop re-runs only tasks with findings, not the entire build
6. `[DIRECT]` mode is read-only — code change requests are rejected back into the full lifecycle

### Documentation Generation

7. All existing features continue to work identically when new config fields are not present (backward compatibility)
8. Bootstrap mode on a fresh project produces all four new document types when their config flags are `true` (default)
9. `playbook.md` contains at least one procedure for each design pattern detected in `architecture.md`
10. `capability-map.md` contains every public function and type, organized into at least 3 task-oriented categories
11. `style-guide.md` (when frontend files exist) documents: file organization, at least one naming convention, and any detected tokens or breakpoints
12. `integration-map.md` contains at least one integration pattern for each pair of modules that communicate
13. CLAUDE.md injection includes project-specific rules (not just boilerplate), with a maximum of 25 rules
14. Incremental mode updates all four new doc types when relevant changes are detected
15. Consistency checking (when enabled) detects and reports at least: direct database queries bypassing Models, `!important` usage, and new files in non-standard locations
16. Config file is backward compatible—existing `config.json` files without new fields work with sensible defaults
17. All new documentation follows the existing style and quality established by the current templates
18. PR descriptions include consistency check results when the check is enabled

---

## 18. Success Metrics

| Metric | Target | Measurement Window |
|--------|--------|--------------------|
| Architectural violations per build cycle | 50% reduction from baseline | After 10 orchestrated sessions |
| First-pass verifier approval rate | >70% of builds pass on first verification | After 20 orchestrated sessions |
| Code duplication incidents | 50% reduction | After 10 orchestrated sessions |
| Frontend consistency violations | 60% reduction in `!important` and hard-coded values | After 5 orchestrated sessions |
| Context recovery success rate | >95% of sessions resume correctly after compaction | Ongoing |

**Tracking note:** These metrics are tracked externally (e.g., via git history analysis, CI reports, manual review of `.ws-session/archive/` data) rather than by the skill system itself. The orchestration framework produces the data (session archives, verification results, consistency reports) but does not self-measure adoption metrics. Teams should establish baselines before onboarding and measure against them periodically.

---

## Appendix A: .ws-session/ Directory Structure

```
.ws-session/
├── orchestrator.json       # ws-orchestrator lifecycle state
├── planner.json            # ws-planner task decomposition state
├── dev.json                # ws-dev implementation state
├── verifier.json           # ws-verifier verification state
└── archive/                # completed session files
    └── [session-id].json
```

**Note:** ws-codebase-documenter does NOT use `.ws-session/`. Its state lives at `documentation/.docstate` and `documentation/config.json`. This is a recognized equivalence — ws-orchestrator reads documenter state from `documentation/.docstate` when needed, not from `.ws-session/`.

**Note:** `.ws-session/` should be added to `.gitignore`. Session files are runtime artifacts, not project files.

---
