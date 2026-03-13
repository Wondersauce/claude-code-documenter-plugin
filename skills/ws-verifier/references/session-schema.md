# ws-verifier Session Schema & Error Handling Reference

> Load this reference when initializing/recovering session files or handling errors during verification.

---

## Session File Schema

`.ws-session/verifier.json`:

```json
{
  "skill": "ws-verifier",
  "version": "2.2.0",
  "plugin_version": "2.2.0",
  "session_id": "uuid-v4",
  "project": "project-name",
  "started_at": "ISO-8601",
  "updated_at": "ISO-8601",
  "status": "active | paused | complete | failed",
  "current_step": "step identifier",
  "completed_steps": [],
  "task": {},
  "build_result": {},
  "docs_loaded": [],
  "files_read": [],
  "criteria_results": [],
  "findings": [],
  "overall_status": "pass | partial | fail",
  "pass_rate": "0%",
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
1. If critical doc (playbook, capability-map): return `status: "failed"` immediately
2. If non-critical: log warning, continue with reduced verification scope

### Changed file read failure

If a changed file listed in build results cannot be read:
1. Log: `ERROR: Cannot read changed file [path]: [error]`
2. Record as a HIGH finding: `"Changed file [path] is inaccessible — cannot verify"`
3. Continue with remaining files

### Empty build results

If build results contain no files_changed:
1. Log: `WARNING: No files changed in build results`
2. Mark all acceptance criteria as `fail` (nothing was implemented)
3. Return `status: "fail"` with finding: `"No implementation output to verify"`
