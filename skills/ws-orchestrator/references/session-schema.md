# ws-orchestrator Session Schema & Error Handling Reference

> Load this reference when initializing, recovering, or writing session files, or when handling sub-skill failures or session corruption.

## Session File Schema

`.ws-session/orchestrator.json`:

```json
{
  "skill": "ws-orchestrator",
  "version": "2.2.0",
  "plugin_version": "2.2.0",
  "session_id": "uuid-v4",
  "project": "project-name",
  "started_at": "ISO-8601",
  "updated_at": "ISO-8601",
  "status": "active | paused | plan_approved | build_complete | complete | aborted | failed",
  "current_step": "step identifier",
  "completed_steps": [],
  "docs_bootstrapped": "true | false | deferred",
  "hooks_installed": true,
  "pending_task": "user's task description",
  "task_type": "feature | bugfix | refactor | documentation | infrastructure",
  "task_area": "frontend | backend | fullstack | devops",
  "current_plan": [],
  "execution_manifest": {},
  "completed_tasks": [],
  "original_branch": "main",
  "feature_branch": "ws/a1b2-add-user-preferences",
  "current_task_branch": null,
  "merged_task_branches": [],
  "task_iteration_counts": {},
  "current_task_index": 0,
  "max_iterations": 3,
  "docs_updated": false,
  "token_usage": {
    "orchestrator": 0,
    "planner": 0,
    "tasks": [],
    "final_documenter": 0,
    "total": 0
  },
  "outputs": {},
  "errors": [],
  "notes": ""
}
```

**`token_usage` structure:**

The `orchestrator` and `planner` fields track tokens consumed by the orchestrator context and the planner Task() call respectively. The `tasks` array contains one entry per execution item (task or group), structured as:

```json
{
  "task_title": "short title from task definition",
  "skill_tokens": {
    "dev": 0,
    "verifier": 0,
    "documenter": 0
  },
  "retries": 0
}
```

When the verifier sends a task back to ws-dev for iteration, the dev and verifier token counts for that task are **cumulative** — add each iteration's tokens to the running total. Increment `retries` by 1 for each iteration cycle (verifier fail/partial → ws-dev re-invocation). A task that passes on the first attempt has `retries: 0`.

`final_documenter` tracks tokens for the Step 5 final documentation pass.

`total` is the sum of all token counts across all fields.

**Token tracking (v2.2.0+):**

Token usage is automatically accumulated by the SubagentStop hook into `.ws-session/token-log.json`. The `token_usage` field in `orchestrator.json` is populated at session completion (Step 5.4) by reading and aggregating the token log. The orchestrator does NOT manually record tokens after each Task() call — the hook handles this.

At Step 5.4, read `.ws-session/token-log.json` and aggregate entries by `skill` field to produce the `token_usage` summary. If the token log is missing or empty, set all counts to `0` and note in `errors[]`.

Token counts are informational metadata — never block or warn based on token counts.

**Fields removed from v1.0.0:**
- `iteration_count` — replaced by per-task `task_iteration_counts`
- `verification_findings` — now per-task, transient between build/verify calls
- `plan_conflicts` — handled inline in per-task loop
- `completed_groups` — groups still work but merge into per-task loop via shared branches

**Fields added in v2.2.0:**
- `hooks_installed` — whether hooks have been installed in `.claude/settings.json`

**Fields removed in v2.2.0:**
- `boot_block_installed` — replaced by `hooks_installed`. Boot block enforcement moved to SessionStart and UserPromptSubmit hooks.

**Fields added in v2.1.0:**
- `plugin_version` — the plugin version that created this session (read from `.claude-plugin/plugin.json`). Used by Step 0 to detect version mismatches on recovery.
- `token_usage` — per-skill token tracking for the session (see structure above)

**Fields added in v2.0.0:**
- `original_branch` — the branch the user was on when the session started (for abort rollback)
- `feature_branch` — the session's feature branch (created after plan approval)
- `current_task_branch` — the active task sub-branch (null when between tasks)
- `merged_task_branches` — history of merged task branches
- `task_iteration_counts` — per-task iteration tracking (keyed by task_id)
- `current_task_index` — index into execution_order for recovery

### State update rules

- Write the session file atomically after **every** state transition
- Always update `updated_at` on each write
- Never delete the session file — archive on completion
- The session file must be valid, human-readable JSON at all times
- On write failure, log the error and present to user

---

## Error Handling

### Sub-skill invocation failure

If a `Task()` call fails to invoke (skill not found, crash, timeout):

1. Log the error to `.ws-session/orchestrator.json` under `errors[]`
2. Present to user:
   ```
   Sub-skill [name] failed: [error]
   Options:
   1. Retry
   2. Skip this task (continue to next task)
   3. Abort session (discard all work)
   ```
3. Await user instruction
4. If option 3: trigger the Abort Flow (Step 4.9)

### Session file corruption

If `.ws-session/orchestrator.json` cannot be parsed:

1. Log: `Session file corrupted. Starting fresh session.`
2. Rename corrupted file to `.ws-session/orchestrator.json.corrupted.[timestamp]`
3. Ask user to describe the current task state
4. Initialize a new session
