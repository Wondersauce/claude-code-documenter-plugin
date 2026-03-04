---

# PRD: Task Grouping and Batched Execution

## Document Info

- **Author**: Marc Cracco (CIO, Wondersauce)
- **Date**: March 2026
- **Plugin**: ws-coding-workflows
- **Status**: Living Document
- **Depends On**: ws-coding-workflows v2.1.0

---

## 1. Problem Statement

The current ws-orchestrator lifecycle spawns one `Task()` call per task definition regardless of task size, complexity, or relationship to adjacent tasks. This creates three concrete inefficiencies:

**Fixed Task() overhead on small tasks.** Each `Task()` call carries fixed costs: a new API call, fresh context startup, SKILL.md loading, documentation loading, and structured result passing back to the orchestrator. For a low-complexity task — a single file change following a documented pattern — this overhead can exceed the cost of the work itself.

**Sequential execution of independent tasks.** ws-orchestrator processes tasks in dependency order but always sequentially. Tasks with no dependency relationship between them — which the planner's `depends_on` DAG already identifies — are safe to run concurrently but never do.

**Repeated documentation loading.** When multiple tasks share the same playbook procedure, area, and module context, each Task() independently loads the same documentation. A set of three related backend endpoint tasks each loads `playbook.md`, `capability-map.md`, and `architecture.md` in full. The documentation load is the most expensive part of each Task() context and it is being paid N times for work that shares the same knowledge base.

The planner already produces all the information needed to solve these problems — playbook procedure, area, module context, complexity estimate, and dependency relationships — but this information is not used to optimize execution.

---

## 2. Objective

Introduce a **grouping phase** to ws-planner that clusters tasks sharing the same execution context into batched groups before returning the plan to ws-orchestrator. Update ws-orchestrator to execute groups as single Task() calls. Update ws-dev to execute multiple tasks in a single context window. Update ws-verifier to verify groups as single verification units.

This reduces:
- Total Task() calls for plans containing multiple related low and medium tasks
- Documentation loading duplication within a session
- Token overhead from repeated context setup

Without changing:
- The correctness guarantees of the plan → build → verify → document lifecycle
- The dependency ordering enforcement
- The isolation between genuinely unrelated tasks
- Any existing SKILL.md behavior for single-task execution

**Note on parallelism:** The dependency DAG produced by ws-planner contains sufficient information to identify tasks eligible for concurrent execution. Parallel Task() invocation is explicitly deferred to a future version. This PRD delivers efficiency gains through reduced Task() call count and documentation deduplication only. The execution manifest structure defined here is designed to support parallelism as a future layer without requiring structural changes.

---

## 3. Scope

### In Scope

- ws-planner: new Step 4.5 — Group Tasks
- ws-planner: new Section 5.8 — Validate Group Integrity
- ws-planner: updated session schema with `task_groups`, `ungrouped_tasks`, `execution_manifest`
- ws-planner: updated result contract to return execution manifest alongside flat task array
- ws-orchestrator: updated Step 3.3 to store execution manifest
- ws-orchestrator: updated Step 3.4 to display grouping summary to user
- ws-orchestrator: updated Step 4 — Build to execute groups as single Task() calls
- ws-orchestrator: updated Step 5 — Verify to pass group-aware input to ws-verifier
- ws-orchestrator: updated Step 5.3 finding-to-task mapping for group re-queuing
- ws-orchestrator: updated session schema
- ws-dev: updated Step 0 — Session Recovery for group compaction recovery
- ws-dev: updated Step 1.1 — Accept Task Input to detect group invocation
- ws-dev: group execution flow (Steps 1–5 group variants)
- ws-dev: updated result contract for group results with per-task attribution
- ws-dev: updated session schema
- ws-verifier: updated Step 1.1 — Accept Verification Input for group-aware input
- ws-verifier: updated Step 1.3 — Read Changed Files with task_id attribution
- ws-verifier: group verification flow
- ws-verifier: updated finding format with `task_id`, `group_id`, and optional `line` fields
- ws-verifier: updated result contract with per-task attribution
- ws-verifier: updated session schema

### Out of Scope

- Parallel Task() execution (deferred — execution manifest supports it but orchestrator does not implement it in this version)
- Changes to ws-codebase-documenter
- Changes to ws-dev/frontend or ws-dev/backend sub-skill routing logic
- Changes to the fullstack nested Task() orchestration
- Changes to the boot block or environment validation steps

---

## 4. Grouping Model

### 4.1 Group Definition

A **task group** is a set of two or more tasks that share sufficient execution context to be implemented in a single ws-dev invocation without loss of correctness or quality.

A group has:
- A single `area` — all tasks are frontend or backend, never mixed, never fullstack
- A single `playbook_procedure` — all tasks follow the same documented procedure
- Overlapping documentation context — same modules or modules covered by the same procedure
- No dependency relationships between the tasks within the group
- Combined complexity within the batching threshold defined in Section 4.3

### 4.2 Grouping Criteria — All Must Be Met

For two or more tasks to be eligible for grouping, every criterion below must be satisfied:

| Criterion | Rule |
|-----------|------|
| Same area | All tasks have identical `area` field |
| Not fullstack | Tasks with `area: "fullstack"` are never grouped — they already use nested Task() orchestration internally and batching them would create conflicting execution layers |
| Same playbook procedure | All tasks reference the same `playbook_procedure` |
| Shared module context | At least one module is common across all tasks in the group. A task "touches" a module if any file in its `files_to_create` or `files_to_modify` arrays resides within that module's directory as documented in `documentation/architecture.md` |
| No intra-group dependency | No task in the candidate set has any other task in the candidate set in its `depends_on` array, directly or transitively |
| No file conflicts | No single file path appears in the `files_to_create` array of one task and the `files_to_modify` array of another task in the same group — this would create an implicit ordering dependency |
| Combined complexity threshold | The combination of tasks falls within the threshold defined in Section 4.3 |

If any criterion is not met, the tasks are not grouped. There is no partial grouping — a task either fully qualifies for a group or executes independently.

### 4.3 Complexity Threshold

The following combinations are eligible for grouping:

| Combination | Group eligible | Rationale |
|-------------|---------------|-----------|
| low + low | Yes | Both tasks small, clear efficiency win |
| low + low + low | Yes | Combined stays within medium territory |
| low + medium | Yes | Combined fits comfortably in a focused context |
| low + low + medium | Yes | Combined approaches but does not exceed high territory |
| medium + medium | No | Combined approaches high territory — isolation earns its cost |
| Any high | No | Always executes independently |
| low + medium + medium | No | Combined exceeds high territory |

Maximum group size: **4 tasks**. Beyond this the combined context approaches high-complexity territory and the quality argument for isolation begins to apply.

**Group-level complexity formula:**

A group's `estimated_complexity` is determined as follows:
- If the group contains any `medium` task: group complexity is `medium`
- If the group contains 3 or more `low` tasks: group complexity is `medium`
- Otherwise: group complexity is `low`

This is recorded in the group object and used by ws-orchestrator for session state tracking.

### 4.4 Shared Context Object

Every group carries a `shared_context` object that ws-dev and ws-verifier use to load documentation efficiently:

```json
{
  "area": "backend",
  "playbook_procedure": "Add REST Endpoint",
  "docs_to_load": [
    "documentation/playbook.md",
    "documentation/capability-map.md",
    "documentation/architecture.md"
  ],
  "modules": ["users", "auth"],
  "reuse": [
    {
      "capability": "UserService.findById",
      "location": "src/services/UserService.ts",
      "usage_pattern": "import { UserService } from 'src/services/UserService'"
    }
  ]
}
```

`docs_to_load` is the union of all documents any task in the group would have loaded individually, deduplicated. `reuse` is the union of all reuse opportunities across all tasks in the group, deduplicated by capability name.

---

## 5. Specification Changes by Skill

### 5.1 ws-planner

#### New Step 4.5 — Group Tasks

Insert after Step 4 (Decompose into Sub-tasks) and before Step 5 (Validate Completeness).

**Purpose:** Analyze the task definition array produced in Step 4 and cluster eligible tasks into groups. Ungrouped tasks remain as individual task definitions and execute independently.

**Procedure:**

**4.5.1 Build the dependency graph**

From the `depends_on` fields across all task definitions, construct the full dependency graph. Record for each task: its direct dependencies, its transitive dependencies, and whether it is a dependency of any other task.

**4.5.2 Compute grouping keys**

For each task, compute its grouping key:
```
grouping_key = [area, playbook_procedure]
```

Tasks with the same grouping key are candidates for grouping. Immediately remove from consideration any task where:
- `area` is `"fullstack"`
- `estimated_complexity` is `"high"`
- `estimated_complexity` is `"medium"` and its only candidate partners are also `"medium"`

**4.5.3 Form candidate sets**

For each unique grouping key with two or more candidate tasks:

a. Remove any task that has a dependency relationship (direct or transitive) with any other task in the candidate set

b. Remove any task where a file in its `files_to_create` appears in another candidate task's `files_to_modify`

c. Check module overlap: for tasks to remain in the same candidate set, at least one module must be common across all tasks in the set. A task touches a module if any file in its `files_to_create` or `files_to_modify` resides within that module's directory per `documentation/architecture.md`. If no common module exists, attempt to split the candidate set into subsets that do share a module.

d. Apply the complexity threshold from Section 4.3. If the combination exceeds the threshold, remove the highest-complexity task from the candidate set and leave it ungrouped.

e. If two or more tasks remain: this is a valid group. If only one remains: leave it ungrouped.

**4.5.4 Enforce maximum group size**

If more than 4 tasks qualify for a single group: form the primary group from the 4 tasks with the most overlapping module context (most files in common modules). Leave remaining qualified tasks ungrouped — they may form their own group if they satisfy all criteria among themselves after the primary group is formed.

**4.5.5 Construct group objects**

For each valid group:

```json
{
  "group_id": "uuid-v4",
  "group_type": "batched",
  "estimated_complexity": "low | medium",
  "shared_context": {
    "area": "backend",
    "playbook_procedure": "Add REST Endpoint",
    "docs_to_load": [
      "documentation/playbook.md",
      "documentation/capability-map.md",
      "documentation/architecture.md"
    ],
    "modules": ["users", "auth"],
    "reuse": []
  },
  "tasks": [
    { ...full task definition... },
    { ...full task definition... }
  ],
  "depends_on_groups": []
}
```

`depends_on_groups` is populated by mapping the `depends_on` task IDs of any task in the group to their containing group IDs or ungrouped task IDs. This becomes the group-level dependency used by ws-orchestrator for execution ordering.

**4.5.6 Build the execution manifest**

```json
{
  "groups": [...],
  "ungrouped_tasks": [...],
  "execution_order": [
    { "type": "group", "id": "group-uuid-1" },
    { "type": "task", "id": "task-uuid-1" },
    { "type": "group", "id": "group-uuid-2" }
  ]
}
```

`execution_order` is a topologically sorted list at the group/task level, respecting all dependency relationships. ws-orchestrator walks this list sequentially.

**4.5.7 Log grouping results**

```
Grouping: [X] tasks → [Y] groups + [Z] ungrouped tasks
Groups formed:
  Group [id]: "[task title 1]", "[task title 2]" — procedure: [procedure], area: [area]
Ungrouped:
  "[task title]" — reason: [high complexity | unique procedure | no module overlap | dependency conflict | fullstack]
Estimated Task() calls: [N] (down from [original task count])
```

**4.5.8 Update session state**

Update `.ws-session/planner.json`:
- Set `task_groups` to the groups array
- Set `ungrouped_tasks` to the ungrouped task array
- Set `execution_manifest` to the full execution manifest
- Set `current_step` to `"5"`

#### New Section 5.8 — Validate Group Integrity

Add as the final item in Step 5 (Validate Completeness), after existing validation items 5.1–5.7.

**5.8 Validate group integrity**

For each group in `task_groups`:

- [ ] All tasks in the group share the same `area`
- [ ] No task in the group has `area: "fullstack"`
- [ ] All tasks in the group share the same `playbook_procedure`
- [ ] No task in the group has `estimated_complexity: "high"`
- [ ] The combination satisfies the threshold table in Section 4.3
- [ ] No intra-group dependency exists between any two tasks in the group
- [ ] No file conflict exists (no file in `files_to_create` of one task appears in `files_to_modify` of another)
- [ ] At least one common module is shared across all tasks in the group
- [ ] Group size does not exceed 4 tasks

For `execution_order`:
- [ ] The list is a valid topological sort of the dependency DAG at the group/task level — no item appears before an item it depends on

If any validation fails: dissolve the offending group and perform the following three operations atomically:

1. Remove the group from `task_groups`
2. Move all tasks that were in the group to `ungrouped_tasks`
3. In `execution_order`, replace the single `{ "type": "group", "id": "[group-id]" }` entry with one `{ "type": "task", "id": "[task-id]" }` entry per dissolved task, inserted at the same position in the sequence and in the same order the tasks appeared in the group's `tasks` array

After all group validations are complete, verify that every `id` referenced in `execution_order` resolves to either a group in `task_groups` or a task in `ungrouped_tasks`. If any `id` is unresolvable, log an error and remove the orphaned entry from `execution_order`.

Record the dissolution in `issues[]`:
```
"group-integrity: Group [id] dissolved — [reason]. [N] tasks reinserted into execution_order at position [pos]."
```

Do not return `status: "failed"` for group integrity failures — ungrouped execution is always a valid fallback.

#### Updated Result Contract

The planner result `outputs` object gains the execution manifest and grouping summary:

```json
{
  "outputs": {
    "tasks": [...],
    "task_groups": [...],
    "ungrouped_tasks": [...],
    "execution_manifest": {
      "groups": [...],
      "ungrouped_tasks": [...],
      "execution_order": [...]
    },
    "reuse_summary": {
      "capabilities_found": 0,
      "capabilities_used": 0
    },
    "docs_loaded": [],
    "grouping_summary": {
      "total_tasks": 6,
      "groups_formed": 2,
      "tasks_in_groups": 4,
      "ungrouped_tasks": 2,
      "estimated_task_calls_saved": 2
    }
  }
}
```

The flat `tasks` array is preserved for backward compatibility. `execution_manifest` is what ws-orchestrator uses for execution.

#### Updated Session File Schema

Add to `.ws-session/planner.json`:

```json
{
  "task_groups": [],
  "ungrouped_tasks": [],
  "execution_manifest": {
    "groups": [],
    "ungrouped_tasks": [],
    "execution_order": []
  }
}
```

#### Re-planning Behavior

Re-planning always recomputes groups from scratch. When ws-orchestrator re-invokes ws-planner with a `feedback` parameter (Step 3.5), Step 4.5 runs in full after decomposition produces the updated task array. Previous group assignments are not preserved — they are derived state, not user input, and any task modification can change grouping eligibility. The new execution manifest replaces the previous one entirely.

---

### 5.2 ws-orchestrator

#### Updated Step 3.3 — Write Plan to Session

When storing the plan after planner result evaluation:

Update `.ws-session/orchestrator.json`:
- Set `current_plan` to the flat task array (preserved for user-facing display and backward compatibility)
- Set `execution_manifest` to the planner's `execution_manifest`
- Set `current_step` to `"3.4"`

#### Updated Step 3.4 — Present Plan to User

The plan summary displayed to the user includes grouping information:

```
## Development Plan

**Task:** [original task description]
**Type:** [type] | **Area:** [area]
**Sub-tasks:** [count total] ([X] in [Y] batched groups, [Z] independent)

| # | Title | Complexity | Procedure | Batch |
|---|-------|-----------|-----------|-------|
| 1 | Add GET /users/:id | low | Add REST Endpoint | Group A |
| 2 | Add PATCH /users/:id | low | Add REST Endpoint | Group A |
| 3 | Add user migration | medium | Add Data Model | — |

**Execution:** [N] Task() calls ([original count] tasks, [saved] calls saved by grouping)

Approve this plan? [Y / request changes]
```

#### Updated Step 4 — Build

**4.0 Load execution manifest**

Read `execution_manifest` from `.ws-session/orchestrator.json`. Walk `execution_order` sequentially.

**4.1 For each item in execution_order:**

**If item `type` is `"task"` (ungrouped):**

Behavior is identical to the current Step 4.1. Determine sub-skill from `task.area`. Invoke `Task(ws-dev/[area])` with the single task definition. Evaluate result. Record in `completed_tasks[]`.

**If item `type` is `"group"`:**

**4.1.1 Determine sub-skill**

All tasks in a group share the same `area`. Use `group.shared_context.area` to determine the sub-skill. Frontend groups invoke `Task(ws-dev/frontend)`. Backend groups invoke `Task(ws-dev/backend)`.

**4.1.2 Invoke ws-dev with group**

```
Task(ws-dev/[area]) with:
  - group: [full group object including group_id, shared_context, and tasks array]
  - project: [project name]
  - iteration_findings: [group-level findings from ws-verifier, if re-build iteration]
```

The presence of the `group` field signals ws-dev that this is a batched invocation.

**4.1.3 Evaluate group result**

The group result contains per-task results. The top-level `status` is the worst-case across all task results. Evaluate:

- If `status: "success"`: record group in `completed_groups[]`, extract per-task results into `completed_tasks[]`, continue
- If `status: "partial"`: record group and per-task results, log issues, continue
- If `status: "blocked"`: log architectural issue with the specific task that blocked, present to user, await instruction — may require re-planning
- If `status: "failed"`: log error, present to user, await instruction

**4.1.4 Update session state**

After each group completes:
- Append full group result to `completed_groups[]`
- Append all per-task results from `task_results[]` into `completed_tasks[]` (ws-verifier consumes the flat array)
- Update `current_step`

**4.2 Build complete**

When all items in `execution_order` are processed:
- Set `status` to `"build_complete"`
- Set `current_step` to `"5"`
- Add `"4"` to `completed_steps`

#### Updated Step 5 — Verify

**5.0 Prepare verification input**

```json
{
  "plan": [...flat task array from current_plan...],
  "build_results": [...completed_tasks flat array...],
  "execution_manifest": {...},
  "completed_groups": [...],
  "project": "project-name"
}
```

**5.1 Invoke ws-verifier** with the above input.

**5.3 Finding-to-task mapping (updated for groups)**

When findings are returned and iteration is required:

For each finding, the finding carries a `task_id` and optionally a `group_id`. Use these fields directly rather than deriving task association from file paths alone.

**Re-queuing logic:**

- If a finding's `task_id` belongs to a group (identified by `group_id`): re-queue the **entire group**, not just the individual task. The group's shared context is preserved on re-queue.
- Attach findings to the group re-queue as a merged `iteration_findings` array. Each finding retains its `task_id` attribution so ws-dev knows which task to re-implement.
- Tasks in the group without findings in the current iteration are **not re-implemented** — they carry forward their most recent successful `task_results` entry.
- If findings span multiple groups: each affected group is re-queued independently.
- If a finding's `task_id` belongs to an ungrouped task: re-queue that task individually as before.

**Carry-forward baseline across multiple iterations:**

On each re-queue, the carry-forward baseline for each task in the group is the most recent `task_results` entry for that `task_id` stored in `completed_groups`. Tasks without findings in the current iteration carry forward their last result entry unchanged. This applies consistently across all iterations — on iteration 3, a task that passed on iteration 1 and has had no findings since carries its iteration 1 result forward.

#### Updated Session File Schema

Add to `.ws-session/orchestrator.json`:

```json
{
  "execution_manifest": {},
  "completed_groups": [],
  "completed_tasks": []
}
```

`completed_tasks` is the flat extraction of all per-task results from all group and ungrouped task executions. It is the backward-compatible structure ws-verifier receives.

---

### 5.3 ws-dev

#### Updated Step 0 — Session Recovery

The existing Step 0 logic is extended with a group recovery path:

**Standard recovery (unchanged):**

1. Check for `.ws-session/dev.json`
2. If found and `status` is `active` or `paused` **and `group_id` is null**: standard single-task recovery — read file, log resume, continue from `current_step`
3. If not found or `status` is `complete`: initialize new session, continue with Step 1

**Group recovery (new):**

4. If found and `status` is `active` or `paused` **and `group_id` is non-null**: this is a group recovery after compaction or interruption.

   a. Read the session file completely
   
   b. Log: `Resuming ws-dev group session [session_id], group: [group_id]`
   
   c. Read `task_results` to determine which tasks in the group have already completed. A task is considered complete if it has an entry in `task_results` with `status: "success"` or `status: "partial"`.
   
   d. Identify the first task in `group.tasks` (in order) that does not have a completed entry in `task_results`
   
   e. Log: `Group recovery: [N] of [total] tasks complete. Resuming from task: [title]`
   
   f. Resume group execution from that task. Completed tasks are not re-executed — their `task_results` entries are carried forward unchanged.
   
   g. The shared documentation from `shared_context.docs_to_load` must be re-loaded — it is not persisted in the session file. Log: `Re-loading shared context documentation for group recovery`

**Nested invocation (unchanged):**

If invoked with `nested: true`: skip all session file operations. Return structured result directly to parent.

#### Updated Step 1.1 — Accept Task Input

ws-dev now accepts either a single task definition or a group. Detect invocation type by checking for the `group` field:

**Single task invocation (unchanged):**
```json
{
  "task_definition": { ...single task... },
  "project": "...",
  "iteration_findings": []
}
```

**Group invocation (new):**
```json
{
  "group": {
    "group_id": "uuid",
    "group_type": "batched",
    "estimated_complexity": "low | medium",
    "shared_context": {
      "area": "backend",
      "playbook_procedure": "...",
      "docs_to_load": [...],
      "modules": [...],
      "reuse": [...]
    },
    "tasks": [ ...task definition array... ]
  },
  "project": "...",
  "iteration_findings": []
}
```

If `group` field is present: execute the Group Execution Flow below. If absent: execute the existing single-task flow unchanged.

#### Group Execution Flow

**Step 1 (group) — Load shared context**

Load documentation from `group.shared_context.docs_to_load`. Load once for the entire group. Log:

```
Group invocation: [task count] tasks, procedure: [procedure], area: [area]
Loading shared documentation (once for group): [doc list]
```

Write initial session state to `.ws-session/dev.json`:
- Set `group_id` to `group.group_id`
- Set `task_results` to empty array
- Set `status` to `"active"`

**Step 2 (group) — Pre-implementation checklist**

Run the standard pre-implementation checklist once against the shared context. Additionally verify:

```
- [x] All tasks share area: [area]
- [x] All tasks share procedure: [procedure]
- [x] No file conflicts between tasks confirmed
- [x] Execution order within group: [task titles in order]
- [x] Reuse capabilities loaded: [count]
```

**Step 3 (group) — Sequential implementation**

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
     "files_changed": [...],
     "issues": []
   }
   ```
6. Update `updated_at` in the session file

If any task returns `blocked` or `failed`: stop group execution immediately. Return the group result with the blocking task identified.

**Step 4 (group) — Per-task self-verification**

Run self-verification independently for each task in the group — both implemented tasks and carried-forward tasks. For carried-forward tasks, use their existing `task_results` entry as the self-verification record (they were already verified on a previous iteration).

For each implemented task, record independently:
```json
{
  "task_id": "...",
  "criteria_results": [],
  "constraint_results": [],
  "playbook_violations": []
}
```

Do not aggregate across tasks. ws-verifier requires per-task evidence.

**Step 5 (group) — Write session file and return group result**

Update `.ws-session/dev.json`:
- Set `status` to `"complete"`
- Ensure all `task_results` entries are written

Return to ws-orchestrator:

```json
{
  "skill": "ws-dev",
  "session_id": "uuid-v4",
  "group_id": "uuid",
  "status": "success | partial | blocked | failed",
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
  "issues": [],
  "next_action": "..."
}
```

`carried_forward: true` on a task result means that task was not re-implemented in this invocation — its result is from a previous iteration. ws-verifier uses this to skip re-verification of carried-forward tasks whose previous verification passed.

**Top-level `status`** is the worst-case status across all task results, including carried-forward tasks. A carried-forward task with `status: "partial"` contributes `partial` to the group status.

#### Updated Session File Schema

Add to `.ws-session/dev.json`:

```json
{
  "group_id": null,
  "task_results": []
}
```

`group_id` is null for single-task invocations. `task_results` accumulates per-task results during group execution and is the source of truth for group recovery after compaction.

---

### 5.4 ws-verifier

#### Updated Step 1.1 — Accept Verification Input

ws-verifier now receives group-aware input:

```json
{
  "plan": [...flat task array...],
  "build_results": [...flat completed_tasks array...],
  "execution_manifest": {...},
  "completed_groups": [...group results with task_results...],
  "project": "..."
}
```

Detect group-aware input by checking for `completed_groups`. If present and non-empty, use the group verification flow alongside single-task verification. The flat `build_results` and `plan` arrays remain the primary input for all existing verification logic — group structures provide attribution and efficiency only.

#### Updated Step 1.3 — Read Changed Files

For group results, read all files from all `task_results[].files_changed` arrays within each group result. Each file read is attributed to its originating task via `task_id`:

```
Reading changed file: [path] (task: [task_id], action: created/modified)
```

This attribution is carried through all verification steps.

Skip reading files from task results where `carried_forward: true` and the task's previous verification status was `pass` — those files have not changed and their verification result is already known.

#### Group Verification Flow

Verification logic across all domains (Steps 2–6) is unchanged. Every domain is still checked for every task. The efficiency gain is that tasks sharing a group are verified in the same Task() context rather than requiring separate verification invocations, and shared documentation is loaded once.

**For each group in `completed_groups`:**

1. Log: `Verifying group [group_id]: [task count] tasks`

2. For each task in the group: run the full verification sequence (Steps 2–6) using documentation already loaded in Step 1.2. Each task is verified independently — acceptance criteria, pattern compliance, reuse, constraints, and documentation currency are all checked per-task.

3. All findings carry `task_id` and `group_id` attribution:

```json
{
  "task_id": "...",
  "group_id": "...",
  "severity": "HIGH | MEDIUM | LOW",
  "domain": "acceptance | pattern | reuse | constraint | documentation",
  "file": "path/to/file",
  "line": 42,
  "description": "what's wrong",
  "expected": "what should be there",
  "found": "what was found",
  "recommended_fix": "specific actionable fix"
}
```

**Note on the `line` field:** `line` is a new addition to the finding format in this version. It is optional — not all findings can be attributed to a specific line number (for example, a missing ARIA label on a component, or a missing migration file). When a specific line can be identified, include it. When it cannot, omit the field rather than using a placeholder value.

**Note on `task_id` and `group_id` on findings:** These fields are new additions to the finding format. For findings on ungrouped tasks, `group_id` is null and `task_id` identifies the task. Both fields are required on findings from group verification.

#### Updated Result Contract

```json
{
  "skill": "ws-verifier",
  "session_id": "uuid-v4",
  "status": "pass | partial | fail",
  "summary": "...",
  "outputs": {
    "findings": [
      {
        "task_id": "...",
        "group_id": "...",
        "severity": "HIGH | MEDIUM | LOW",
        "domain": "acceptance | pattern | reuse | constraint | documentation",
        "file": "path/to/file",
        "line": 42,
        "description": "...",
        "expected": "...",
        "found": "...",
        "recommended_fix": "..."
      }
    ],
    "task_results": [
      {
        "task_id": "...",
        "group_id": "...",
        "criteria_met": "X/Y",
        "pass_rate": "percentage",
        "status": "pass | partial | fail"
      }
    ],
    "criteria_met": "X/Y",
    "pass_rate": "percentage"
  },
  "issues": [],
  "next_action": "..."
}
```

`task_id` and `group_id` on findings enable ws-orchestrator's finding-to-task mapping to correctly identify which group to re-queue and which tasks within that group have findings. `group_id` is null for findings on ungrouped tasks.

#### Updated Session File Schema

Add to `.ws-session/verifier.json`:

```json
{
  "group_verification_state": []
}
```

`group_verification_state` tracks which groups have been verified and their per-group status, enabling compaction recovery mid-verification:

```json
{
  "group_verification_state": [
    {
      "group_id": "uuid",
      "status": "complete | in-progress | pending",
      "tasks_verified": ["task_id_1", "task_id_2"],
      "findings_count": 2
    }
  ]
}
```

On session recovery, ws-verifier reads `group_verification_state` to determine which groups are already complete and resumes from the first group with `status: "pending"` or `"in-progress"`.

---

## 6. Backward Compatibility

All changes are additive. The existing single-task execution path in ws-dev, ws-orchestrator, and ws-verifier is completely unchanged. A plan that produces zero groups — all tasks ungrouped — flows through the system identically to current behavior.

The planner's flat `tasks` array in the result contract is preserved. The flat `completed_tasks` array in the orchestrator session is preserved. ws-verifier's existing finding format fields are all preserved — `task_id`, `group_id`, and `line` are additive fields that do not break any existing consumer of the finding structure.

---

## 7. Acceptance Criteria

### ws-planner

1. Step 4.5 runs after decomposition and before validation on every planning invocation
2. Fullstack tasks are never grouped regardless of any other criterion
3. High complexity tasks are never grouped
4. Medium + medium combinations are never grouped
5. Low + medium combinations are grouped when all other criteria are met
6. Maximum group size of 4 is enforced
7. No intra-group dependency relationships exist in any formed group
8. No file conflicts exist within any formed group
9. Module overlap is verified using file path membership against `architecture.md` module directories
10. The execution manifest's `execution_order` is a valid topological sort
11. Section 5.8 validation runs on every formed group before the result is returned
12. Groups that fail Section 5.8 validation are dissolved to ungrouped tasks without returning `status: "failed"`
13. Re-planning recomputes groups from scratch — previous group assignments are not preserved
14. A plan with no groupable tasks produces empty `task_groups` and all tasks in `ungrouped_tasks` without error
15. Group complexity formula is applied correctly per Section 4.3

### ws-orchestrator

16. Step 4 walks `execution_manifest.execution_order` rather than the flat task array
17. Group invocations pass the full group object to ws-dev
18. Per-task results from group results are extracted into `completed_tasks[]`
19. Finding-to-task mapping re-queues the entire group when any finding has a `group_id`
20. Carry-forward baseline is the most recent `task_results` entry per `task_id` across all iterations
21. The plan summary displayed to the user includes grouping and Task() call count information
22. Single-task ungrouped execution is unchanged

### ws-dev

23. Group invocation is detected via the `group` field
24. Step 0 detects `group_id` non-null in an active session and executes group recovery
25. Group recovery resumes from the first task without a completed `task_results` entry
26. Group recovery re-loads shared documentation before resuming
27. Documentation is loaded once per group invocation
28. Each task is implemented sequentially in group order
29. `files_changed` entries carry `task_id` attribution
30. Per-task self-verification results are preserved separately in `task_results`
31. On iteration re-queue: only tasks with findings are re-implemented; others carry forward their most recent `task_results` entry
32. Carry-forward is applied consistently across all iterations — not just the first
33. Group result `status` is the worst-case across all task results including carried-forward tasks
34. `carried_forward: true` is set on task results that were not re-implemented in the current invocation
35. Single-task invocation is unchanged
36. Nested invocation with `nested: true` is unchanged

### ws-verifier

37. Group results in `completed_groups` are verified in the same Task() context
38. Files from carried-forward tasks with previous `pass` status are not re-read
39. All findings carry `task_id` and `group_id` attribution
40. `line` field is included when a specific line can be identified, omitted when it cannot
41. Per-task criteria results are preserved in `task_results` in the result contract
42. `group_verification_state` is written to the session file after each group is verified
43. Session recovery reads `group_verification_state` and resumes from the first non-complete group
44. Top-level `pass_rate` and `criteria_met` aggregate correctly across both grouped and ungrouped tasks
45. Single-task verification is unchanged

---

## 8. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Task() calls per session | Reduction proportional to groupable task count | Compare session archives before and after |
| Documentation load operations per session | Reduction equal to tasks saved by grouping | `shared_context_used.docs_loaded` in group results |
| Verification quality on grouped tasks | No regression vs. single-task baseline | Pass rate comparison across session archives |
| Grouping rate on typical plans | >30% of eligible tasks grouped | `grouping_summary` in planner results |
| Group recovery success rate | >95% of interrupted group sessions resume correctly | Session archive status field distribution |
