# ws-debugger Session Schema & Error Handling Reference

> Load this reference when initializing, recovering, or writing session files, or when handling investigation failures.

## Session File Schema

`.ws-session/debugger.json`:

```json
{
  "skill": "ws-debugger",
  "version": "2.3.0",
  "plugin_version": "2.3.0",
  "session_id": "uuid-v4",
  "project": "project-name",
  "started_at": "ISO-8601",
  "updated_at": "ISO-8601",
  "status": "active | paused | complete",
  "current_step": "step identifier",
  "completed_steps": [],
  "bug_report": "original bug report from user",
  "task_area": "frontend | backend | fullstack",
  "docs_loaded": [],
  "initial_leads": {
    "error_messages": [],
    "reproduction_context": "",
    "affected_area": "",
    "symptoms": [],
    "bug_category": "runtime-error | logic-bug | type-error | ui-visual | ui-behavioral | performance | data-integrity | integration-failure | intermittent | build-compile | security | unknown"
  },
  "investigation": {
    "strategy_used": "strategy name from investigation-strategies.md",
    "files_investigated": [],
    "git_forensics": {
      "commands_run": [],
      "suspect_commits": [],
      "regression_range": null
    },
    "web_research": {
      "performed": false,
      "queries": [],
      "findings": []
    },
    "depth": {
      "files_read": 0,
      "max_files": 25,
      "leads_followed": 0,
      "leads_abandoned": []
    }
  },
  "hypotheses": [],
  "root_cause": {},
  "fix_description": {},
  "fix_complexity": "low | medium | high",
  "secondary_issues": [],
  "errors": []
}
```

### State update rules

- Write the session file atomically after every state transition
- Always update `updated_at` on each write
- Never delete the session file — the orchestrator manages archival
- The session file must be valid, human-readable JSON at all times
- On write failure, log the error and present to orchestrator

### Investigation depth tracking

The `investigation.depth` object enforces bounding:
- `files_read`: increment each time a new source file is read
- `max_files`: hard ceiling (default 25, adjusted per strategy)
- `leads_followed`: count of distinct investigation threads pursued
- `leads_abandoned`: leads that were deprioritized with reason

When `files_read` reaches `max_files`, the debugger must stop investigating and produce a result from current evidence — even if that means returning `status: "partial"`.

---

## Error Handling

### Documentation read failure

If a documentation file cannot be read (permissions, corrupt, etc.):

1. Log: `WARNING: Failed to read [document path]: [error]`
2. Continue investigation — documentation enhances but does not gate investigation
3. Record the failure in `errors[]`

### Source file read failure

If a source file in the investigation path cannot be read:

1. Log: `WARNING: Cannot read [file path]: [error]`
2. Record the failed file in `investigation.files_investigated` with `status: "unreadable"`
3. Note the gap in the hypothesis — this weakens confidence
4. Continue with next available lead

### Git command failure

If a git forensics command fails:

1. Log: `WARNING: Git command failed: [command] — [error]`
2. Continue investigation without git history context
3. Note in `investigation.git_forensics` that the command failed

### Web research failure

If web search or fetch fails:

1. Log: `WARNING: Web research failed: [query/url] — [error]`
2. Continue investigation from source code evidence only
3. Do not lower confidence solely because web research was unavailable

### Investigation timeout / depth exceeded

If the debugger reaches its file read limit without a high-confidence root cause:

1. Assemble all evidence collected so far
2. Rank hypotheses by confidence
3. Return with `status: "partial"` and `next_action` describing what additional investigation might help
4. Do not attempt to read more files past the limit
