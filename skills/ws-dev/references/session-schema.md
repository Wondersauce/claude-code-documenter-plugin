# ws-dev Session Schema & Error Handling Reference

> Load this reference when initializing, recovering, or writing session files, or when handling errors.

## Session File Schema

`.ws-session/dev.json`:

```json
{
  "skill": "ws-dev",
  "version": "2.1.0",
  "plugin_version": "2.1.0",
  "session_id": "uuid-v4",
  "project": "project-name",
  "started_at": "ISO-8601",
  "updated_at": "ISO-8601",
  "status": "active | paused | complete | blocked | unfeasible | failed",
  "current_step": "step identifier",
  "completed_steps": [],
  "mode": "build | iterate",
  "task_branch": "ws/a1b2-add-user-preferences-be-task-01",
  "feature_branch": "ws/a1b2-add-user-preferences",
  "task_definition": {},
  "group_id": null,
  "task_results": [],
  "iteration_findings": [],
  "docs_loaded": [],
  "checklist": {},
  "files_changed": [],
  "self_verification": {},
  "build_gate": {},
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

## Error Handling

### Documentation read failure

If a document cannot be read:
1. If critical doc: return `status: "blocked"` immediately
2. If non-critical: log warning, continue with reduced context

### File write failure

If a file cannot be created or modified:
1. Log: `ERROR: Cannot write [path]: [error]`
2. Record in `errors[]`
3. If the file is essential to the task: return `status: "failed"`
4. If non-essential: continue, note in `issues[]`

### Reuse target missing

If a reuse capability cannot be found at its documented location:
1. Log: `WARNING: Reuse target [capability] not found at [location]`
2. Search for it in nearby locations (it may have been moved)
3. If found elsewhere: use it, note the location discrepancy in `issues[]`
4. If not found: return `status: "blocked"` — do not re-implement it
