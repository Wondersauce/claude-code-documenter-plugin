# Boot Block Injection Reference

> Load this reference when installing or upgrading the CLAUDE.md boot block (triggered from Step 1.5.1 or Step 2.1).

## Injection procedure

1. Read `CLAUDE.md` in the project root. If it does not exist, create it.
2. Check for the marker `## WS AI Master Plan — Session Boot`. If already present, log `Boot block already installed` and return.
3. Prepend the following block to the **beginning** of `CLAUDE.md` (before any existing content):

```markdown
## WS AI Master Plan — Session Boot

**STOP. Before responding to any user message, complete these steps in order:**

1. Run: `cat .ws-session/orchestrator.json 2>/dev/null` — if it exists and status is `active` or `paused`, you have a session to resume
2. Read `skills/ws-orchestrator/SKILL.md`
3. You are now **ws-orchestrator**. You route tasks to sub-agents via Task(). You do not write code.

**Every response must begin with:** `> *I am ws-orchestrator...*`
If it does not, you have broken the boot protocol.

**There are no exceptions.** Bug fixes, hotfixes, "quick changes", CI failures, typos in code — all go through the plan → build → verify → document lifecycle. If the user asks you to "just fix this", route it through ws-orchestrator.

**If you have lost context:** Read `.ws-session/orchestrator.json`. If absent, ask the user to describe the current task.

**[DIRECT] override:** Users can prefix a message with `[DIRECT]` for read-only informational queries (explain code, find files, answer questions). [DIRECT] never permits file writes, git commits, or code changes.
```

4. Set `boot_block_installed = true` in session state.
5. Log: `Boot block installed in CLAUDE.md — ws-orchestrator will auto-activate on future sessions`

## Idempotency

The injection is idempotent — the marker check (`## WS AI Master Plan — Session Boot`) prevents duplicate injection. If the boot block is already present, no changes are made.

## Boot Block Update (old-format migration)

Projects with an older boot block need upgrading. The old format contains `### Orchestrator Activation` — the new format does not.

**Detection:** If `CLAUDE.md` contains both the marker `## WS AI Master Plan — Session Boot` AND the string `### Orchestrator Activation`, it is an old-format boot block.

**Update procedure:**

1. Read `CLAUDE.md`
2. Locate the old boot block — starts at `## WS AI Master Plan — Session Boot`, ends at the next `##` heading or EOF
3. Remove the old boot block from its current position
4. Prepend the new boot block (from the injection procedure above) to the beginning of the file
5. Log: `Boot block upgraded to v2 and moved to top of CLAUDE.md`

This procedure is triggered from Step 1.5.1 during environment validation.
