# Fullstack Orchestration Reference

> Load this reference when ws-dev receives a task with `area: "fullstack"`.

### Fullstack Orchestration

For `fullstack` tasks, ws-dev orchestrates the work by splitting it into backend and frontend components and delegating each via nested `Task()` calls. The parent ws-dev instance manages the split, delegation, and result merging.

**Session file ownership:** The parent ws-dev instance owns `.ws-session/dev.json`. Nested `Task()` calls do **not** write their own session files — they return structured results to the parent. The `nested: true` flag is critical — it tells the sub-skill to skip all session file operations.

#### Task Splitting Rules

Analyze the task definition to identify which portions belong to backend vs. frontend:

| Concern | Routes To |
|---------|-----------|
| Data models, schema changes, migrations | Backend |
| API endpoints, route handlers, middleware | Backend |
| Business logic, services, validation rules | Backend |
| External service integrations | Backend |
| UI components, templates, pages | Frontend |
| Client-side state management | Frontend |
| Styling, CSS, design tokens, responsive layouts | Frontend |
| Client-side API integration (fetch calls, SDK wrappers) | Frontend |
| Accessibility (ARIA, keyboard nav, alt text) | Frontend |

**Shared concerns — ownership and coordination:**

| Shared Concern | Owner | Consumer |
|---------------|-------|----------|
| API contract (endpoints, request/response shapes) | Backend defines | Frontend consumes from backend result |
| Shared types/interfaces for API payloads | Backend creates | Frontend imports or references |
| Validation rules (client + server) | Backend is source of truth | Frontend may duplicate for UX — note in `issues[]` |

#### Derived Task Definitions

Create two task definitions derived from the parent fullstack task. Each derived task inherits the parent's `playbook_procedure` (or `structural_guidance` if deferred), `constraints`, and `depends_on`.

**Backend derived task:**
- `task_id`: `[parent_task_id]-be`
- `area`: `backend`
- `acceptance_criteria`: backend-relevant criteria from parent
- `backend_quality`: from parent task (propagated)
- `files_to_create` / `files_to_modify`: backend files from parent
- `reuse`: backend-relevant reuse from parent

**Frontend derived task:**
- `task_id`: `[parent_task_id]-fe`
- `area`: `frontend`
- `acceptance_criteria`: frontend-relevant criteria from parent
- `design_quality`: from parent task (propagated)
- `depends_on`: includes `[parent_task_id]-be`
- `files_to_create` / `files_to_modify`: frontend files from parent
- `reuse`: frontend-relevant reuse from parent
- `backend_context`: populated after backend execution (see below)

**Acceptance criteria splitting:**
- Criteria about data, API behavior, validation, server-side logic → backend
- Criteria about UI, layout, interaction, accessibility, client-side behavior → frontend
- **Integration criteria** (e.g., "user clicks button and data persists") → both tasks get the criterion, each responsible for their half. Mark with `"integration_criterion": true` in both.

#### Quality Tier Propagation

Route quality tiers from the parent fullstack task to the appropriate sub-task:

| Parent Field | Routes To |
|-------------|-----------|
| `design_quality` | Frontend derived task only |
| `backend_quality` | Backend derived task only |

Both can be `"high"` independently — a fullstack task can activate the Design Quality Layer for frontend AND the Production Hardening Layer for backend simultaneously.

#### Execution Sequence

**Backend first, then frontend.** Frontend code typically consumes backend APIs, so the backend must be defined first.

1. **Execute backend:** `Task(ws-dev/backend)` with `nested: true` and the backend derived task
2. **If backend fails:** Do not execute frontend. Return the backend result as the fullstack result with `next_action` indicating the backend issue must be resolved first.
3. **Extract API context** from the backend result:
   - New endpoints created (paths, methods, request/response shapes)
   - Data models defined (field names, types, relationships)
   - Auth requirements for new endpoints
   - Shared types or interfaces created (with file locations)
4. **Attach API context to frontend task** via the `backend_context` field:
   ```json
   {
     "backend_context": {
       "endpoints": [
         {
           "path": "/api/resource",
           "method": "POST",
           "request_shape": "{ field: type }",
           "response_shape": "{ id: string, ... }",
           "auth_required": true
         }
       ],
       "models": ["ModelName"],
       "shared_types_files": ["path/to/types.ts"]
     }
   }
   ```
5. **Execute frontend:** `Task(ws-dev/frontend)` with `nested: true`, the frontend derived task, and the `backend_context`

#### Result Merging

After both sub-tasks complete, merge into a single fullstack result:

- `files_changed`: concatenate from both, preserving area attribution in descriptions
- `self_verification.criteria_results`: merge from both — integration criteria appear in both
- `self_verification.constraint_results`: merge from both
- `self_verification.playbook_violations`: merge from both
- `self_verification.backend_checks`: from backend result
- `self_verification.frontend_checks`: from frontend result
- `issues`: concatenate from both, prefix with `[BE]` or `[FE]` for clarity

**When quality layers are active**, also include:
- `production_intent`: from backend result (if `backend_quality: "high"`)
- `design_intent`: from frontend result (if `design_quality: "high"`)
- `self_verification.backend_quality_checks`: from backend result
- `self_verification.design_quality_checks`: from frontend result

**Status merging** — use worst-case across both sub-tasks:
- `failed` > `blocked` > `unfeasible` > `partial` > `success`

#### Tightly Coupled Fallback

If the task **cannot be cleanly split** — the backend and frontend logic are interleaved in the same files (e.g., Next.js server components, Remix loaders, SvelteKit load functions, or full-stack framework patterns where the same file handles both concerns):

1. Log: `WARNING: Fullstack task has tightly coupled fe/be concerns — executing as single implementation`
2. Do **not** delegate via `Task()` — execute the task directly in the parent ws-dev context
3. Load and apply conventions from both layers:
   - Backend Conventions Layer (Universal Rules + Smart Defaults)
   - Frontend Conventions Layer (Styling, Component, Accessibility, Responsive rules)
4. If `backend_quality: "high"`: run the Production Hardening Phase and apply Quality Domains
5. If `design_quality: "high"`: run the Design Thinking Phase and apply Aesthetic Guidelines
6. Include both `backend_checks` and `frontend_checks` in self-verification
7. Note `"executed_as": "tightly_coupled"` in the result for ws-verifier context

#### Deferred Handling for Fullstack

When the parent fullstack task has `playbook_procedure: null` + `structural_guidance` (deferred/new project):
- Both derived tasks inherit `playbook_procedure: null` and `structural_guidance` from the parent
- Each sub-task independently detects deferred state and uses structural guidance
- No additional deferred handling needed at the orchestration level — the sub-skills handle it
