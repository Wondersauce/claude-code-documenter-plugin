# ws-planner Session Schema, Re-planning & Error Handling Reference

> Load this reference when initializing/recovering session files, handling re-planning invocations, or handling errors.

---

## Session File Schema

`.ws-session/planner.json`:

```json
{
  "skill": "ws-planner",
  "version": "2.3.0",
  "plugin_version": "2.3.0",
  "session_id": "uuid-v4",
  "project": "project-name",
  "started_at": "ISO-8601",
  "updated_at": "ISO-8601",
  "status": "active | paused | complete | failed",
  "current_step": "step identifier",
  "completed_steps": [],
  "task_description": "original task from ws-orchestrator",
  "task_type": "feature | bugfix | refactor | documentation | infrastructure",
  "task_area": "frontend | backend | fullstack | devops",
  "docs_loaded": [],
  "task_analysis": {
    "relevant_patterns": [],
    "relevant_procedures": [],
    "affected_modules": [],
    "ambiguities": []
  },
  "reuse_opportunities": [],
  "task_definitions": [],
  "task_groups": [],
  "ungrouped_tasks": [],
  "execution_manifest": {
    "groups": [],
    "ungrouped_tasks": [],
    "execution_order": []
  },
  "validation_checklist": {},
  "outputs": {},
  "errors": [],
  "notes": ""
}
```

### State update rules

- Write the session file atomically after **every** state transition
- Always update `updated_at` on each write
- Never delete the session file — ws-orchestrator manages archival
- The session file must be valid, human-readable JSON at all times
- On write failure, log the error and return `status: "failed"`

---

## Re-planning with Feedback

When ws-orchestrator re-invokes ws-planner with user feedback (Step 3.5 in ws-orchestrator):

1. Read the previous plan from `.ws-session/planner.json`
2. Apply the user's feedback to adjust:
   - Add/remove/modify tasks
   - Adjust acceptance criteria
   - Change decomposition granularity
   - Address flagged ambiguities
3. Re-run validation (Step 5)
4. Return updated result

The session file retains the history — `notes` field records what changed and why.

**Re-planning and groups:** Re-planning always recomputes groups from scratch. When Step 4.5 runs after decomposition produces the updated task array, previous group assignments are not preserved — they are derived state, not user input, and any task modification can change grouping eligibility. The new execution manifest replaces the previous one entirely.

---

## Error Handling

### Documentation read failure

If a document cannot be read (permission, encoding, etc.):

1. Log: `ERROR: Cannot read [path]: [error]`
2. If critical doc: return `status: "failed"` immediately
3. If non-critical: continue with warning

### Task decomposition failure

If the task cannot be meaningfully decomposed:

1. Return as a single task with `estimated_complexity: "high"`
2. Set `issues[]` with: `"Task could not be decomposed further — may require re-scoping"`
3. Set status to `"partial"`

### Circular dependencies

If dependency analysis reveals a cycle:

1. Log: `ERROR: Circular dependency detected: [task_a] <-> [task_b]`
2. Break the cycle by merging the dependent tasks
3. Record in `issues[]`
