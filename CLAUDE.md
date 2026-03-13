# WS Coding Workflows — Project Guide

## What This Is

A Claude Code plugin (v2.3.0) that enforces a deterministic development lifecycle: **plan → build → verify → document**. Every coding session follows the same process regardless of task type, preventing architectural drift, code duplication, and styling entropy as projects grow.

The plugin uses Markdown-based skills (executable specifications) backed by Claude Code hooks for enforcement. No compiled code, no runtime dependencies.

## Repository Structure

```
.claude-plugin/
├── plugin.json              # Plugin manifest (name, version, author)
└── marketplace.json         # Marketplace metadata

scripts/
└── hooks/
    ├── lib/session-utils.sh       # Shared session detection utilities
    ├── drift-guard.sh             # PreToolUse — enforce skill write boundaries
    ├── track-file-change.sh       # PostToolUse — auto-track file changes for ws-dev
    ├── git-guard.sh               # PreToolUse — enforce git conventions
    ├── save-session-snapshot.sh   # PreCompact — snapshot session state before compaction
    └── track-tokens.sh            # SubagentStop — auto-accumulate token usage

hooks-config.json                  # Hook configuration template (installed to .claude/settings.json)

skills/
├── ws-orchestrator/SKILL.md       # Lifecycle manager — routes work, never writes code
├── ws-debugger/
│   ├── SKILL.md                   # Bug investigation — reads code, identifies root cause, produces fix descriptions
│   └── references/
│       ├── session-schema.md      # Session file schema and error handling
│       └── investigation-strategies.md  # Bug-type strategies, git forensics, web research, bounding rules
├── ws-planner/SKILL.md            # Task decomposition — produces structured task definitions
├── ws-dev/
│   ├── SKILL.md                   # Implementation parent — routes by area, handles fullstack
│   ├── frontend/SKILL.md          # Frontend conventions, design quality, a11y rules
│   ├── backend/SKILL.md           # Backend conventions, production hardening
│   └── devops/SKILL.md            # CI/CD, IaC, containers, deployment conventions
├── ws-verifier/SKILL.md           # Independent verification — reads and judges, never fixes
└── ws-codebase-documenter/
    ├── SKILL.md                   # Documentation generator (bootstrap/incremental/regenerate)
    └── references/
        ├── stacks/                # Stack-specific patterns (nodejs, python, go, rust, etc.)
        ├── consistency-rules.md   # Architecture/frontend/integration violation rules
        ├── doc-templates.md       # All 15 documentation template specs
        ├── frontend-detection.md  # CSS/JS/design token scanning procedures
        └── docusaurus.md          # Docusaurus sync procedures
```

## Build System

There is no build system. This is a pure skill-based plugin:

- No package.json, no compiled artifacts, no runtime dependencies
- Skills are Markdown files that define executable behavior for Claude Code
- State persists via JSON files in `.ws-session/` (gitignored)
- Generated documentation outputs to `documentation/` in the target project

## Skill Hierarchy

```
ws-orchestrator (entry point — never writes code)
├── Task(ws-debugger)        → bug investigation, root cause analysis (bugfix only)
├── Task(ws-planner)         → structured task definitions
├── Task(ws-dev)             → implementation
│   ├── ws-dev/frontend      → UI, styling, accessibility
│   ├── ws-dev/backend       → APIs, services, data models
│   └── ws-dev/devops        → CI/CD, IaC, containers, deployment
├── Task(ws-verifier)        → pass/partial/fail verdict
└── Task(ws-codebase-documenter) → documentation updates
```

Each skill runs in an isolated `Task()` context. No shared memory between skills — all communication is via structured JSON inputs/outputs and session state files.

## Session State

Every skill maintains state in `.ws-session/[skill-name].json`. State files:
- Written atomically after every step transition
- Enable recovery after context compaction, interruption, or restart
- Are never deleted by the creating skill (orchestrator manages archival)
- Must be valid JSON at all times
- Include `plugin_version` to detect version mismatches on recovery

Session schemas are defined in the "Session File Schema" section of each SKILL.md.

### Session Versioning

Every session file includes a `plugin_version` field set to the current version from `.claude-plugin/plugin.json` at session creation time. On recovery (Step 0), each skill compares the session's `plugin_version` against the running plugin version:

- **Orchestrator:** Presents the user with a choice — attempt recovery (with explicit field-by-field validation) or dump the session and start fresh. Recovery will fail and report exactly which fields are missing if the schema has changed.
- **Sub-skills (planner, dev, verifier):** Do not attempt recovery on version mismatch — initialize a fresh session. Sub-skill sessions are short-lived and re-creatable; silent recovery with missing data risks producing incorrect output.

## Hook Architecture

Hooks provide hard enforcement of plugin rules via Claude Code's hooks API. They are installed automatically by the orchestrator (Step 1.5) into `.claude/settings.json`.

| Event | Hook | Purpose |
|-------|------|---------|
| **SessionStart** | command + prompt | Detect active sessions, enforce orchestrator activation on every conversation |
| **UserPromptSubmit** | prompt | Enforce orchestrator routing for all coding work (second enforcement layer) |
| **PreToolUse** (Write/Edit) | `drift-guard.sh` | Block file writes that violate skill boundaries |
| **PreToolUse** (Bash) | `git-guard.sh` | Block force pushes, enforce merge conventions |
| **PostToolUse** (Write/Edit) | `track-file-change.sh` | Auto-track file changes for ws-dev |
| **PreCompact** | `save-session-snapshot.sh` | Snapshot session state before context compaction |
| **SubagentStop** | `track-tokens.sh` + prompt | Auto-accumulate tokens, verify build gate execution |

**Enforcement is mandatory.** The orchestrator lifecycle is not optional — all coding work routes through plan → build → verify → document. The only bypass is `[DIRECT]`-prefixed messages for read-only queries.

## Key Conventions

- **Skills never exceed their boundaries.** Enforced by PreToolUse hooks — the verifier physically cannot write source code, the planner can only write its session file, etc.
- **Bugs go through investigation first.** When `task_type = bugfix`, the orchestrator dispatches to ws-debugger before planning. The debugger reads source code, identifies the root cause, and returns an enriched fix description that the planner decomposes into tasks.
- **Documentation drives implementation.** ws-dev reads playbook.md and capability-map.md before writing any code. If these docs don't exist, the project must bootstrap first.
- **Verification is independent.** ws-verifier loads changed files and judges against task definitions — it has no knowledge of ws-dev's reasoning.
- **Iteration is bounded.** Failed verification triggers re-dispatch to ws-dev (max 3 iterations). After 3 failures, the user decides.
- **State recovery is mechanical, not speculative.** Step 0 in every skill reads the session file and resumes from the last completed step. No guessing.
- **File changes are hook-tracked.** ws-dev no longer manually tracks `files_changed[]` — the PostToolUse hook writes to `.ws-session/file-changes.json` automatically.

## Testing

No automated test suite exists yet. Current validation is runtime:
- ws-dev self-verifies before returning
- ws-verifier independently validates output
- ws-codebase-documenter runs consistency rules

See CLAUDE.md design notes (below) for testing strategy recommendations.

## Design Decisions & Known Limitations

### No Concurrency
Tasks execute sequentially. This limits blast radius on failure (only one task's work is at risk) and avoids merge conflict complexity. The cost is wall-clock time — token usage is roughly equivalent either way.

### Documenter Is Monolithic
ws-codebase-documenter generates all documentation types in a single context. This is intentional — documentation requires holistic codebase awareness. Splitting it into sub-skills would risk inconsistency between documents.

### No Offline/Local Model Support
This plugin requires Claude-level reasoning to follow 500-800 line prescriptive specifications with JSON state management. Current open-weights models cannot reliably execute these workflows. This may change as local models improve.

### Token Tracking (Not Cost Tracking)
Token usage is automatically tracked by the SubagentStop hook, which accumulates usage into `.ws-session/token-log.json`. The orchestrator reads the log at session completion to present the summary. There is no mechanism to convert tokens to dollar costs — token counts are informational metadata only.

## Modifying Skills

When editing SKILL.md files:
- Preserve the frontmatter (name, description, argument-hint)
- Maintain Step 0 (Session Recovery) as the first operational step in every skill
- Keep the Session File Schema section in sync with actual state file usage
- Update version fields in session schemas when making breaking changes to state format
- Test changes against a controlled project before merging

## Modifying Hooks

When editing hook scripts in `scripts/hooks/`:
- Maintain compatibility with the `session-utils.sh` shared library
- Hook scripts must be executable (`chmod +x`)
- PreToolUse hooks exit 0 to allow, exit 2 to block (with reason on stdout)
- PostToolUse hooks are fire-and-forget — they cannot block operations
- Update `hooks-config.json` version when adding/removing/modifying hooks
- Test hooks locally before committing — a broken hook can block all file operations

## Version History

- **v2.3.0** — Current. Adds ws-debugger skill for bug investigation with 12 bug-category strategies, git forensics, conditional web research, and depth-bounded investigation. Bugfix tasks now route through debugger → planner → dev → verifier.
- **v2.2.0** — Hook-based enforcement (SessionStart, UserPromptSubmit, PreToolUse drift guards, PostToolUse file tracking, PreCompact snapshots, SubagentStop token tracking and build gate). Removes CLAUDE.md boot block in favor of hooks. Automated migration from boot block to hooks.
- **v2.1.0** — Fullstack orchestration, task grouping, design quality layer, session versioning, token tracking.
- **v2.0.0** — Lifecycle restructure, dev sub-skill upgrades, per-task verification loop.
- **v1.0.0** — Initial release with linear plan-build-verify cycle.
