# WS Coding Workflows — Project Guide

## What This Is

A Claude Code plugin (v2.1.0) that enforces a deterministic development lifecycle: **plan → build → verify → document**. Every coding session follows the same process regardless of task type, preventing architectural drift, code duplication, and styling entropy as projects grow.

The plugin is entirely Markdown-based — no compiled code, no runtime dependencies. Skills are executable specifications that Claude Code interprets and follows.

## Repository Structure

```
.claude-plugin/
├── plugin.json              # Plugin manifest (name, version, author)
└── marketplace.json         # Marketplace metadata

skills/
├── ws-orchestrator/SKILL.md       # Lifecycle manager — routes work, never writes code
├── ws-planner/SKILL.md            # Task decomposition — produces structured task definitions
├── ws-dev/
│   ├── SKILL.md                   # Implementation parent — routes by area, handles fullstack
│   ├── frontend/SKILL.md          # Frontend conventions, design quality, a11y rules
│   └── backend/SKILL.md           # Backend conventions, production hardening
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
├── Task(ws-planner)         → structured task definitions
├── Task(ws-dev)             → implementation
│   ├── ws-dev/frontend      → UI, styling, accessibility
│   └── ws-dev/backend       → APIs, services, data models
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

Session schemas are defined in the "Session File Schema" section of each SKILL.md.

## Key Conventions

- **Skills never exceed their boundaries.** The orchestrator doesn't write code. The dev agent doesn't make architectural decisions. The verifier doesn't fix issues.
- **Documentation drives implementation.** ws-dev reads playbook.md and capability-map.md before writing any code. If these docs don't exist, the project must bootstrap first.
- **Verification is independent.** ws-verifier loads changed files and judges against task definitions — it has no knowledge of ws-dev's reasoning.
- **Iteration is bounded.** Failed verification triggers re-dispatch to ws-dev (max 3 iterations). After 3 failures, the user decides.
- **State recovery is mechanical, not speculative.** Step 0 in every skill reads the session file and resumes from the last completed step. No guessing.

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

### No Cost Tracking
There is no mechanism to convert token usage to dollar costs. Users may be on subscription plans, API billing, or hybrid setups — too many variables for accurate conversion. Token counts per session could be tracked as informational metadata.

## Modifying Skills

When editing SKILL.md files:
- Preserve the frontmatter (name, description, argument-hint)
- Maintain Step 0 (Session Recovery) as the first operational step in every skill
- Keep the Session File Schema section in sync with actual state file usage
- Update version fields in session schemas when making breaking changes to state format
- Test changes against a controlled project before merging

## Version History

- **v2.1.0** — Current. Fullstack orchestration, task grouping, design quality layer.
- **v2.0.0** — Lifecycle restructure, dev sub-skill upgrades, per-task verification loop.
- **v1.0.0** — Initial release with linear plan-build-verify cycle.
