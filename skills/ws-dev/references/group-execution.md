# Group Execution Flow Reference

> Load this reference when ws-dev is invoked with a `group` field (batched invocation from ws-orchestrator).

## Group Execution Flow

This flow is used when ws-dev is invoked with a `group` field (batched invocation from ws-orchestrator). The single-task flow above remains unchanged for non-group invocations.

**Branch model for groups:** A group gets ONE task sub-branch (since all tasks in a group share context). The branch name uses the group_id: `[feature_branch]-group-[group_id_short]`. All tasks in the group are implemented on this single branch. On verification pass, the entire group branch merges into the feature branch. The orchestrator manages the branch — ws-dev receives the `task_branch` name and checks it out.

### Step 1 (group) — Load shared context

Load documentation from `group.shared_context.docs_to_load`. Load once for the entire group. Log:

```
Group invocation: [task count] tasks, procedure: [procedure], area: [area]
Loading shared documentation (once for group): [doc list]
```

Write initial session state to `.ws-session/dev.json`:
- Set `group_id` to `group.group_id`
- Set `task_results` to empty array
- Set `status` to `"active"`

### Step 2 (group) — Pre-implementation checklist

Run the standard pre-implementation checklist once against the shared context. Additionally verify:

```
- [x] All tasks share area: [area]
- [x] All tasks share procedure: [procedure]
- [x] No file conflicts between tasks confirmed
- [x] Execution order within group: [task titles in order]
- [x] Reuse capabilities loaded: [count]
```

### Step 3 (group) — Sequential implementation

Process tasks in the order they appear in `group.tasks`.

**Determine which tasks to implement:**

If `iteration_findings` are present and carry `task_id` attribution:
- Implement only tasks whose `task_id` appears in `iteration_findings`
- For all other tasks in the group: carry forward the most recent `task_results` entry for that `task_id` from the session file. Do not re-execute them.
- Log: `Iteration re-queue: implementing [N] of [total] tasks. Carrying forward: [task titles]`

If no `iteration_findings` (first execution): implement all tasks.

**For each task to implement:**

1. Log: `Implementing task [N/total]: [title]`
2. Follow the playbook procedure already loaded in Step 1
3. Use shared reuse capabilities from `shared_context.reuse`
4. After each file change, append to `files_changed[]` with `task_id` attribution:
   ```json
   {
     "task_id": "...",
     "path": "path/to/file",
     "action": "created | modified",
     "description": "what was done"
   }
   ```
5. After completing the task, write a task result entry to `task_results[]` in the session file:
   ```json
   {
     "task_id": "...",
     "status": "success | partial | blocked | failed",
     "files_changed": [],
     "issues": []
   }
   ```
6. Update `updated_at` in the session file

If any task returns `blocked` or `failed`: stop group execution immediately. Return the group result with the blocking task identified.

### Step 4 (group) — Build, Test & Lint Gate + Per-task self-verification

**First, run the Build, Test & Lint Gate (Step 4.1 from the single-task flow) once for the entire group.** All tasks share a single branch, so one build/test/lint run covers the group. Record the results and attribute them to every task in the group.

Then run self-verification independently for each task in the group — both implemented tasks and carried-forward tasks. For carried-forward tasks, use their existing `task_results` entry as the self-verification record (they were already verified on a previous iteration).

For each implemented task, record independently:

```json
{
  "task_id": "...",
  "build_gate": {},
  "criteria_results": [],
  "constraint_results": [],
  "playbook_violations": [],
  "frontend_checks": [],
  "backend_checks": []
}
```

> **Sub-skill checks in group mode:** When tasks are implemented via ws-dev/frontend or ws-dev/backend (nested invocations), those sub-skills produce `frontend_checks` and `backend_checks` respectively. In group mode, these checks must be attributed per-task — include them in each task's self-verification record above. If a task does not involve a sub-skill area, omit that field or leave it as an empty array.

Do not aggregate across tasks. ws-verifier requires per-task evidence.

### Step 5 (group) — Write session file and return group result

Update `.ws-session/dev.json`:
- Set `status` to `"complete"`
- Ensure all `task_results` entries are written

Return to ws-orchestrator:

```json
{
  "skill": "ws-dev",
  "session_id": "uuid-v4",
  "mode": "build | iterate",
  "task_branch": "ws/a1b2-add-user-preferences-group-abc1",
  "group_id": "uuid",
  "status": "success | partial | blocked | unfeasible | failed",
  "summary": "one-line outcome for the group",
  "task_results": [
    {
      "task_id": "...",
      "status": "success | partial | blocked | failed",
      "files_changed": [
        {
          "task_id": "...",
          "path": "path/to/file",
          "action": "created | modified",
          "description": "..."
        }
      ],
      "self_verification": {
        "criteria_results": [],
        "constraint_results": [],
        "playbook_violations": []
      },
      "issues": [],
      "carried_forward": false
    }
  ],
  "shared_context_used": {
    "docs_loaded": [],
    "reuse_applied": []
  },
  "build_gate": {
    "build": { "status": "pass | fail | skipped", "command": "..." },
    "lint": { "status": "pass | fail | skipped", "command": "..." },
    "tests": { "status": "pass | fail | skipped", "command": "...", "passed_count": 0, "failed_count": 0 },
    "attempts": 1,
    "pre_existing_errors": []
  },
  "issues": [],
  "next_action": "..."
}
```

`carried_forward: true` on a task result means that task was not re-implemented in this invocation — its result is from a previous iteration. ws-verifier uses this to skip re-verification of carried-forward tasks whose previous verification passed.

**Top-level `status`** is the worst-case status across all task results, including carried-forward tasks. A carried-forward task with `status: "partial"` contributes `partial` to the group status.
