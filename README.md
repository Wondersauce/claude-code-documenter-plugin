# WS Coding Workflows

A Claude Code plugin that replaces ad-hoc AI development with a deterministic, process-enforced system. Every session follows the same lifecycle: **plan → build → verify → document**.

Implemented entirely as Claude Code skills, a top-level orchestrator routes work to specialized sub-skills that each operate in isolated `Task()` contexts. No sub-skill shares context with the orchestrator or each other. All state persists to disk so sessions survive compaction, interruption, and restart.

## Problem

Claude Code is effective at project start. As complexity grows, five failure modes emerge:

- **Architectural drift** — Claude loses awareness of established patterns and invents alternatives
- **Code duplication** — Without a map of what exists, Claude re-implements utilities
- **CSS/styling entropy** — `!important` overrides accumulate, design tokens get bypassed
- **Inconsistent cross-module integration** — Different modules call each other through different patterns
- **Context loss between sessions** — Decisions live in chat history, not structured form

## Solution

A five-layer framework addressing each root cause:

| Layer | What It Does | Implemented By |
|-------|-------------|----------------|
| Project Constitution | Primes agent with context, rules, conventions before every task | `CLAUDE.md` + `documentation/` via ws-codebase-documenter |
| Sub-Agent Architecture | Routes work to specialists with bounded, focused context | ws-orchestrator via `Task()` delegation |
| Documentation-as-You-Build | Reads docs before building, updates after completing | ws-dev read step + ws-codebase-documenter update step |
| Refactoring Checkpoints | Periodic consistency audits; catch drift before it compounds | ws-verifier + ws-codebase-documenter incremental scan |
| Guardrails and Validation | Automated checks at every build cycle | ws-verifier findings driving iteration |

## Installation

Inside Claude Code, run:

```
/plugin marketplace add wondersauce/claude-code-plugin

/plugin install ws-coding-workflows@wondersauce-marketplace
```

## Skills

| Skill | Purpose |
|-------|---------|
| [ws-orchestrator](#ws-orchestrator) | Development orchestrator — enforces plan-build-verify-document lifecycle via sub-agent delegation |
| [ws-planner](#ws-planner) | Development planner — produces fully specified task definitions from project documentation |
| [ws-dev](#ws-dev) | Implementation agent — writes code following task definitions, playbook patterns, and documented conventions |
| [ws-verifier](#ws-verifier) | Output verifier — independently reviews implementation against task definitions and conventions |
| [ws-codebase-documenter](#ws-codebase-documenter) | Documentation generator — produces and maintains AI-optimized codebase documentation |

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                    ws-orchestrator                    │
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

### Context Window Isolation

- ws-orchestrator context stays shallow — session state, routing, result evaluation only
- Each `Task()` starts with a clean context, loads only what it needs, returns a structured result
- The main context never accumulates code, diffs, or documentation content
- Compaction loses nothing of substance — the state file has everything

### State Persistence

Every skill maintains its own state file under `.ws-session/`:

```
.ws-session/
├── orchestrator.json       # orchestrator state
├── planner.json            # plan construction state
├── dev.json                # implementation state
├── verifier.json           # verification findings
└── archive/                # completed sessions
```

All state files are written atomically after every state transition, never deleted by the creating skill, and remain valid human-readable JSON at all times.

### Compaction Recovery

Every skill includes a Step 0 that checks for an active session file before doing anything else. If found, it resumes from where it left off. Sessions survive compaction, crashes, and restarts.

---

## ws-orchestrator

The default operating mode for Claude Code sessions. Never writes code, never modifies documentation, never performs implementation. Routes work to sub-skills, manages session state, evaluates results, drives the lifecycle.

### Usage

```
/ws-orchestrator Add a user preferences API endpoint with GET and PATCH support
```

### Lifecycle

```
plan → build → verify → document
```

1. **Plan** (Step 3) — `Task(ws-planner)` produces structured task definitions
2. **Build** (Step 4) — `Task(ws-dev)` implements tasks in dependency order
3. **Verify** (Step 5) — `Task(ws-verifier)` independently reviews output
4. **Document** (Step 6) — `Task(ws-codebase-documenter)` updates project docs

### Boot Sequence

1. **Session recovery** — check for active session in `.ws-session/orchestrator.json`
2. **Environment validation** — verify `.ws-session/` dir, check for `documentation/`, detect project name, verify all sub-skills installed
3. **Receive task** — accept and classify task, check if docs need bootstrapping
4. **Execute lifecycle** — plan → build → verify → document with iteration support

### Required Sub-skills

ws-orchestrator hard-fails if any of these are missing:

- `ws-planner` — Development planning
- `ws-dev` — Implementation (frontend/backend/fullstack)
- `ws-verifier` — Output verification
- `ws-codebase-documenter` — Documentation maintenance

### Iteration Loop

If ws-verifier returns `fail` or `partial`, ws-orchestrator re-sends only the tasks with findings back to ws-dev (up to 3 iterations by default). If convergence fails, findings are presented to the user for decision.

### Manual Override

Prefix any message with `[DIRECT]` to bypass orchestration for informational queries:

```
[DIRECT] What does UserService.findById return?
```

Any request that would result in code changes is routed through the full lifecycle regardless.

### Drift Prevention

ws-orchestrator declares its identity in every response and contains no implementation guidance. If implementation-level content appears in the main context, it proactively suggests `Task()` delegation.

---

## ws-planner

Given a task description and project documentation, produces fully specified, structured development plans. Determines what to build, how to structure it per existing patterns, how to decompose into sub-tasks, and what constraints apply.

### How It Works

1. **Load documentation** — reads playbook.md (critical), capability-map.md (critical), architecture.md, and conditionally style-guide.md and integration-map.md
2. **Analyze task** — identify type, area, relevant patterns, flag ambiguities
3. **Check for reuse** — search capability map for existing functionality, document exact import paths
4. **Decompose** — break into atomic sub-tasks (one ws-dev invocation each) with dependency ordering
5. **Validate** — every criterion testable, every file mod references a playbook pattern, no open architectural decisions
6. **Return** — structured Task Definition array

### Task Definition Format

Each sub-task includes:

- Task ID, title, type, area, description
- Acceptance criteria (testable, verifiable by ws-verifier)
- Constraints (explicit requirements from the planner)
- Files to create and modify
- Documentation updates needed
- Dependencies on other tasks
- Complexity estimate (low/medium/high)
- Playbook procedure to follow
- Reuse opportunities with exact import paths

### Key Behaviors

- **Hard-fails** if playbook.md or capability-map.md is missing
- **Never guesses** at patterns not in the documentation
- **Re-planning** — when ws-orchestrator re-invokes with user feedback, reads previous plan and applies adjustments

---

## ws-dev

Implements a single, fully-specified task from ws-planner. Reads documentation before writing any code, follows exact patterns from the task definition, reuses identified existing capabilities. Does not make architectural decisions.

### Sub-skills

| Sub-skill | Area |
|-----------|------|
| **ws-dev/frontend** | UI components, styling, client-side logic, accessibility |
| **ws-dev/backend** | API endpoints, data models, services, business logic |
| **ws-dev/fullstack** | Tasks spanning both — splits into frontend/backend and delegates via nested `Task()` calls |

### How It Works

1. **Load context** — read task definition, load playbook, capability-map, and area-specific docs
2. **Pre-implementation checklist** — verify playbook procedure found, reuse targets exist, all constraints and criteria understood
3. **Implement** — follow playbook procedure exactly, reuse all identified capabilities, update session after each file change
4. **Self-verify** — review each criterion and constraint honestly, note all issues (does not self-pass)
5. **Return** — files changed, checklist, self-verification results, issues

### Architectural Blocking

If implementation reveals an uncovered architectural issue, ws-dev **stops immediately** and returns `status: "blocked"` with the decision needed. It never makes architectural decisions on its own.

### Frontend Conventions Layer

Non-negotiable rules for all frontend implementation:

- Always read `style-guide.md` before writing any CSS/SCSS/styled-components — blocks if missing
- Never use `!important` except in documented override patterns
- Never hard-code values that exist as design tokens
- All interactive elements must have ARIA labels
- All images must have alt text
- All new components must respect documented responsive breakpoints
- Always use established component patterns from capability-map.md

### Backend Conventions Layer

Non-negotiable rules for all backend implementation:

- Always use the established data access pattern (service/repository or as documented)
- Never bypass authentication/authorization middleware
- Always use the documented error handling pattern — no raw exceptions in API responses
- All new endpoints must follow the documented request/response envelope format
- Database changes require migration files — never modify schema directly
- All external service calls must go through the established service layer

---

## ws-verifier

Independently reviews ws-dev output against the task definition, project documentation, and coding conventions. Reads, analyzes, and judges — never re-implements.

### Verification Domains

1. **Acceptance criteria** — is each criterion from the task definition met?
2. **Pattern compliance** — does the implementation follow the playbook?
3. **Reuse compliance** — were existing capabilities used as specified?
4. **Constraint compliance** — are all constraints respected?
5. **Documentation currency** — does the output introduce anything requiring doc updates beyond what's planned?

### Finding Severity Levels

| Severity | Definition | Examples |
|----------|-----------|---------|
| **HIGH** | Architectural violation, security bypass, or constraint violation | Direct DB call bypassing service; `!important`; re-implemented existing utility |
| **MEDIUM** | Pattern deviation creating inconsistency | Wrong error format; missing ARIA; inconsistent naming |
| **LOW** | Minor, doesn't violate conventions | Unused import; inconsistent spacing |

### Pass/Fail Thresholds

| Result | Condition |
|--------|-----------|
| **pass** | Zero HIGH findings AND >80% criteria met |
| **partial** | Some criteria met, some findings |
| **fail** | Any HIGH finding OR <50% criteria met |

### How It Works

1. **Load context** — task definition, ws-dev results, playbook, capability-map, all changed files
2. **Verify acceptance criteria** — locate satisfying code, verify correctness, record pass/fail with evidence
3. **Verify pattern compliance** — check playbook procedure adherence, area-specific conventions
4. **Verify reuse compliance** — confirm existing capabilities were used, not re-implemented (re-implementation = HIGH)
5. **Verify constraint compliance** — check each constraint (any violation = HIGH)
6. **Documentation currency** — flag undocumented additions not in planned updates
7. **Produce result** — calculate pass rate, determine overall status, return findings with recommended fixes

---

## ws-codebase-documenter

Scans your codebase and generates structured documentation optimized for AI consumption. Produces both descriptive docs (what code does) and prescriptive docs (how to build new things correctly).

### Usage

Bootstrap (first run):
```
/ws-codebase-documenter bootstrap
```

Incremental updates after code changes:
```
/ws-codebase-documenter update
```

Regenerate a specific document:
```
/ws-codebase-documenter regenerate playbook
/ws-codebase-documenter regenerate style-guide
/ws-codebase-documenter regenerate all
```

Valid regenerate targets: `playbook`, `capability-map`, `style-guide`, `integration-map`, `overview`, `architecture`, `consistency-report`, `all`

### Generated Document Suite

| Document | Type | Purpose |
|----------|------|---------|
| `overview.md` | Descriptive | Project structure, stack, entry points |
| `architecture.md` | Descriptive | Modules, data flow, system boundaries |
| `public/` | Descriptive | Public API and component reference |
| `private/` | Descriptive | Internal implementation reference |
| **`playbook.md`** | **Prescriptive** | Step-by-step procedures for adding new features |
| **`capability-map.md`** | **Prescriptive** | Task-oriented lookup of all existing utilities |
| **`style-guide.md`** | **Prescriptive** | Frontend/CSS conventions and design token registry |
| **`integration-map.md`** | **Prescriptive** | Cross-module integration patterns |

The prescriptive documents (bold) are the critical layer — they tell agents *how* to build things correctly, not just what exists.

### Output Structure

```
documentation/
├── config.json              # Configuration and feature flags
├── .docstate                # State tracking for incremental updates
├── overview.md              # Project purpose and entry points
├── architecture.md          # Component diagrams, data flow, design patterns
├── playbook.md              # Step-by-step procedures for common tasks
├── capability-map.md        # Task-oriented lookup of existing functionality
├── style-guide.md           # Frontend conventions, tokens, and rules
├── integration-map.md       # Cross-module communication patterns
├── public/                  # Public API reference
└── private/                 # Internal implementation reference
```

### Supported Stacks

| Stack | Detection |
|-------|-----------|
| Node.js/TypeScript | `package.json` |
| Python | `requirements.txt`, `pyproject.toml`, `setup.py` |
| Go | `go.mod` |
| Rust | `Cargo.toml` |
| .NET | `*.csproj`, `*.sln` |
| Java | `pom.xml`, `build.gradle` |
| PHP | `composer.json` |

---

## Example Flow

```
User: "Add a user preferences API endpoint with GET and PATCH support"

ws-orchestrator → Task(ws-planner)
  Reads docs, identifies UserService + auth middleware + REST playbook
  Produces 3 sub-tasks with full specifications
  Returns structured plan

ws-orchestrator presents plan → user approves

ws-orchestrator → Task(ws-dev/backend) [Task 3 — model layer]
  Implements migration + UserService methods per playbook

ws-orchestrator → Task(ws-dev/backend) [Tasks 1 & 2 — routes]
  Implements route handlers using UserService per playbook

ws-orchestrator → Task(ws-verifier)
  Finds: all criteria met, 1 MEDIUM (missing rate limit middleware)
  Returns: status=partial

ws-orchestrator iterates: sends Task 2 back to ws-dev/backend with finding
  ws-dev adds rate limiting

ws-orchestrator → Task(ws-verifier) again → status=pass

ws-orchestrator → Task(ws-codebase-documenter) mode=incremental
  Updates capability-map with new UserService methods

ws-orchestrator: status=complete → presents summary
```

## Skill File Structure

```
skills/
├── ws-orchestrator/
│   └── SKILL.md
├── ws-planner/
│   └── SKILL.md
├── ws-dev/
│   ├── SKILL.md              # Base lifecycle + fullstack routing
│   ├── frontend/SKILL.md     # Frontend conventions layer
│   └── backend/SKILL.md      # Backend conventions layer
├── ws-verifier/
│   └── SKILL.md
└── ws-codebase-documenter/
    ├── SKILL.md
    └── references/
```

## License

MIT
