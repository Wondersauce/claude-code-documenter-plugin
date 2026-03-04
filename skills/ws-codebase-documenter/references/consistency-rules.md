# Consistency Rules Reference

Rules checked during incremental documentation updates (step 3.4.5). Each rule includes a detection procedure an AI agent can follow mechanically.

## Table of Contents

1. [Overview](#overview)
2. [Rule Schema](#rule-schema)
3. [Architecture Rules -- High Confidence](#architecture-rules----high-confidence)
4. [Architecture Rules -- Best Effort](#architecture-rules----best-effort)
5. [Frontend Rules -- High Confidence](#frontend-rules----high-confidence)
6. [Frontend Rules -- Best Effort](#frontend-rules----best-effort)
7. [Integration Rules -- High Confidence](#integration-rules----high-confidence)
8. [Integration Rules -- Best Effort](#integration-rules----best-effort)
9. [Stack-Specific Rule Overrides](#stack-specific-rule-overrides)
10. [Consistency Check Execution Procedure](#consistency-check-execution-procedure)
11. [Updating Rules After Documentation Changes](#updating-rules-after-documentation-changes)

---

## Overview

This file defines consistency rules checked during incremental documentation updates (SKILL.md step 3.4.5). Rules detect violations where code changes conflict with established project patterns recorded in `documentation/.docstate` and the generated docs.

Rules are tiered by confidence level:

| Tier | Meaning | Result Label |
|------|---------|--------------|
| **High-confidence** | Deterministic, pattern-matchable checks. Reliable results. | `Violation` |
| **Best-effort** | Heuristic checks that may produce false positives. | `Review Suggested` |

---

## Rule Schema

Every rule follows this format:

```markdown
### RULE-ID: Rule Name

- **Category**: Architecture | Frontend | Integration
- **Confidence**: High | Best-effort
- **Severity**: Error (when strict mode) | Warning
- **Applies to**: [file types or conditions]
- **Requires**: [which generated docs/state: e.g., detected_patterns.rest_endpoint]

**Detection Procedure**:
1. [Step 1]
2. [Step 2]
...

**Violation Condition**: [What constitutes a violation]

**Fix Template**: "[Suggested fix text to include in report]"
```

Use this schema when adding new rules. Every field is required.

---

## Architecture Rules -- High Confidence

### ARCH-001: Routing Pattern Violation

- **Category**: Architecture
- **Confidence**: High
- **Severity**: Error (strict) | Warning
- **Applies to**: New files in controller, handler, or route directories
- **Requires**: `detected_patterns.rest_endpoint.glob`

**Detection Procedure**:

1. Get the list of new files from `git diff --name-status`
2. For each new file, check if it contains route definitions (stack-specific: decorators, annotations, `router.get`, `Route::`, etc.)
3. If it does, compare the file's directory path against `detected_patterns.rest_endpoint.glob`
4. If the file's path does not match the glob, flag it

**Violation Condition**: New file contains route definitions but is NOT in the expected directory.

**Fix Template**: "New endpoint at `{file}` should be in `{expected_dir}` per the project's routing pattern. See `documentation/playbook.md` for the correct procedure."

---

### ARCH-002: Direct Database Query Bypass

- **Category**: Architecture
- **Confidence**: High
- **Severity**: Error (strict) | Warning
- **Applies to**: All source files (exclude test files)
- **Requires**: `detected_patterns.data_access`

**Detection Procedure**:

1. Get the list of changed files from `git diff --name-status`
2. Exclude test files (matching `exclude` patterns in `config.json`)
3. For each changed file, determine the stack and search for raw DB access patterns:

| Stack | Raw DB Access Patterns |
|-------|----------------------|
| PHP | `\$wpdb->`, `DB::raw(`, `DB::select(`, `mysqli_`, `PDO::` direct usage outside Repository classes |
| Node.js | `pool.query(`, `connection.execute(`, `knex.raw(`, `sequelize.query(` outside Model/Repository files |
| Python | `cursor.execute(`, `connection.execute(`, `raw(` outside Model/Manager files |
| Go | `sql.Open(`, `db.Query(`, `db.Exec(` outside repository files |
| Rust | `sqlx::query(` outside repository files |
| .NET | `SqlCommand`, `ExecuteSqlRaw` outside Repository classes |
| Java | `jdbcTemplate.`, `entityManager.createNativeQuery` outside Repository classes |

4. Check if the file resides in the model/repository directory (from `detected_patterns.data_access.glob`)
5. If a pattern matches AND the file is outside the model/repository directory, flag it

**Violation Condition**: Raw DB access pattern found in a file that is NOT in the model/repository directory.

**Fix Template**: "Direct database access at `{file}:{line}`. Use `{model_class}` methods instead per `documentation/playbook.md`."

---

### ARCH-003: Non-Standard Directory Location

- **Category**: Architecture
- **Confidence**: High
- **Severity**: Error (strict) | Warning
- **Applies to**: Newly created source files with stack-matching extensions only
- **Requires**: `detected_patterns` directory globs (all entries), `config.stack`

**Detection Procedure**:

1. Get the list of added files (`A` status) from `git diff --name-status`
2. Filter to source code files only — include files matching the detected stack's extensions:

| Stack | Source Extensions |
|-------|------------------|
| Node.js/TypeScript | `.js`, `.ts`, `.jsx`, `.tsx`, `.mjs`, `.cjs` |
| Python | `.py` |
| Go | `.go` |
| Rust | `.rs` |
| .NET | `.cs`, `.fs`, `.vb` |
| Java | `.java`, `.kt` |
| PHP | `.php` |

3. Exclude files matching these patterns (never flag these):
   ```
   **/migrations/*, **/migrate/*, **/seeds/*, **/seeders/*,
   **/fixtures/*, **/config/*, **/configuration/*,
   **/scripts/*, **/bin/*, **/.github/*, **/docs/*,
   **/documentation/*, *.config.*, *.json, *.yaml, *.yml,
   *.toml, *.xml, *.md, *.txt, *.sql, *.sh
   ```
4. For each remaining file, collect all directory globs from `detected_patterns`
5. Test the file's path against every glob
6. If no glob matches the file's directory, flag it

**Violation Condition**: New source file's path does not match any established directory pattern (after filtering to stack source files and excluding non-source paths).

**Fix Template**: "New file `{file}` doesn't match any established directory pattern. Expected locations: {pattern_list}."

---

## Architecture Rules -- Best Effort

### ARCH-010: Potential Duplicate Functionality

- **Category**: Architecture
- **Confidence**: Best-effort
- **Severity**: Warning
- **Applies to**: New functions, classes, or modules
- **Requires**: `documentation/capability-map.md`

**Detection Procedure**:

1. From the diff, extract the names of new functions/classes/modules
2. Split each name into words (handle camelCase, snake_case, kebab-case, PascalCase):
   ```
   camelCase    -> [camel, case]
   snake_case   -> [snake, case]
   kebab-case   -> [kebab, case]
   PascalCase   -> [pascal, case]
   ```
3. Load all entry names from `documentation/capability-map.md`
4. Split each existing entry name into words using the same method
5. For each new name, compare its word set against each existing entry's word set
6. Calculate overlap: `intersection_count / min(new_words_count, existing_words_count)`
7. If overlap > 50%, flag for review

**Violation Condition**: Word overlap exceeds 50% with an existing capability entry.

**Fix Template**: "New `{name}` may duplicate existing `{existing_name}` in `{module}`. Check `documentation/capability-map.md` before proceeding."

> **Note**: This is a best-effort check. False positives are expected. Label findings as "Review Suggested" not "Violation."

---

### ARCH-011: Naming Convention Deviation

- **Category**: Architecture
- **Confidence**: Best-effort
- **Severity**: Warning
- **Applies to**: New public functions and classes
- **Requires**: Detected naming patterns from codebase scan

**Detection Procedure**:

1. From the diff, extract new public function/class names
2. Load the detected naming convention from `.docstate` or config (camelCase, snake_case, PascalCase, etc.)
3. Test each name against the convention regex:

| Convention | Regex |
|------------|-------|
| camelCase | `^[a-z][a-zA-Z0-9]*$` |
| snake_case | `^[a-z][a-z0-9_]*$` |
| PascalCase | `^[A-Z][a-zA-Z0-9]*$` |
| SCREAMING_SNAKE | `^[A-Z][A-Z0-9_]*$` |
| kebab-case | `^[a-z][a-z0-9-]*$` |

4. If the name does not match the detected convention, flag it

**Violation Condition**: New name does not match the project's detected naming convention pattern.

**Fix Template**: "Name `{name}` doesn't follow the project's `{convention}` convention."

> **Note**: This is a best-effort check. Label findings as "Review Suggested."

---

## Frontend Rules -- High Confidence

### FE-001: !important Usage

- **Category**: Frontend
- **Confidence**: High
- **Severity**: Error (strict) | Warning
- **Applies to**: `*.css`, `*.scss`, `*.less` files
- **Requires**: `config.style_guide.forbidden_patterns` includes `!important`

**Detection Procedure**:

1. Get the list of changed CSS/SCSS/LESS files from `git diff --name-status`
2. For each file, get the diff hunks: `git diff [last_commit]..HEAD -- [file]`
3. Search added lines (lines starting with `+`) for pattern:
   ```regex
   !important
   ```
4. If found on any added line, flag it with the file path and line number

**Violation Condition**: Any `!important` occurrence in changed (added) lines.

**Fix Template**: "`!important` found at `{file}:{line}`. Use more specific selectors instead. See `documentation/style-guide.md`."

---

### FE-002: Inline Styles in Templates

- **Category**: Frontend
- **Confidence**: High
- **Severity**: Error (strict) | Warning
- **Applies to**: `.html`, `.php`, `.jsx`, `.tsx`, `.vue`, `.blade.php`, `.cshtml`, `.erb`, `.twig`, `.hbs`
- **Requires**: `config.style_guide.forbidden_patterns` includes `inline styles`

**Detection Procedure**:

1. Get the list of changed template files from `git diff --name-status`
2. For each file, get the diff hunks
3. Search added lines for pattern:
   ```regex
   style\s*=\s*["']
   ```
4. If found on any added line, flag it

**Violation Condition**: Any inline `style=` attribute in changed (added) lines.

**Fix Template**: "Inline style at `{file}:{line}`. Use CSS classes instead. See `documentation/style-guide.md`."

---

### FE-003: CSS/SCSS File in Wrong Directory

- **Category**: Frontend
- **Confidence**: High
- **Severity**: Error (strict) | Warning
- **Applies to**: New `*.css`, `*.scss`, `*.less` files
- **Requires**: `detected_patterns.frontend_css` glob

**Detection Procedure**:

1. Get the list of added CSS/SCSS/LESS files from `git diff --name-status`
2. For each new file, compare its path against `detected_patterns.frontend_css.glob`
3. If the file is outside the expected directory, flag it

**Violation Condition**: New stylesheet is outside the expected CSS directory.

**Fix Template**: "Stylesheet `{file}` should be in `{expected_dir}`. See `documentation/style-guide.md`."

---

### FE-004: Hardcoded Value Matching Existing Token

- **Category**: Frontend
- **Confidence**: High
- **Severity**: Error (strict) | Warning
- **Applies to**: Changed CSS/SCSS files
- **Requires**: Token list from `documentation/style-guide.md` or detected tokens in `.docstate`

**Detection Procedure**:

1. Load the token value map from `documentation/style-guide.md` or `.docstate`:
   ```
   { "#3b82f6": "--color-primary", "16px": "--spacing-md", ... }
   ```
2. Get the list of changed CSS/SCSS files
3. For each file, get the diff hunks and isolate added lines
4. Extract hex colors from added lines:
   ```regex
   #[0-9a-fA-F]{3,8}
   ```
5. Extract pixel values from added lines:
   ```regex
   \b\d+px\b
   ```
6. Compare each extracted value against the token map
7. If an exact match is found, flag it

**Violation Condition**: A literal value is used where a token variable exists for that exact value.

**Fix Template**: "Hardcoded `{value}` at `{file}:{line}` matches token `{token_name}`. Use `{token_var}` instead."

---

## Frontend Rules -- Best Effort

### FE-010: Class Naming Doesn't Match Methodology

- **Category**: Frontend
- **Confidence**: Best-effort
- **Severity**: Warning
- **Applies to**: Changed CSS/SCSS files
- **Requires**: `config.frontend.methodology` (set during step 2.2b or by user override)

**Detection Procedure**:

1. Load the CSS methodology from `config.frontend.methodology` in `documentation/config.json` (BEM, utility-first, css-modules, etc.). If null or `none`, skip this rule.
2. Get the list of changed CSS/SCSS files
3. Extract new class selectors from added lines:
   ```regex
   \.[a-zA-Z_-][a-zA-Z0-9_-]*
   ```
4. Based on methodology, validate each class name:

| Methodology | Validation Regex |
|-------------|-----------------|
| BEM | `^\.[a-z]([a-z0-9-]*)?(__[a-z]([a-z0-9-]*)?)?(--[a-z]([a-z0-9-]*)?)?$` |
| Utility-first | Check if class is single-purpose (one CSS property) |

5. If a class name does not match the methodology pattern, flag it

**Violation Condition**: New class name does not follow the detected CSS methodology.

**Fix Template**: "Class `{class}` at `{file}:{line}` doesn't follow {methodology} convention."

> **Note**: This is a best-effort check. Label findings as "Review Suggested."

---

### FE-011: JS File Doesn't Follow Init Pattern

- **Category**: Frontend
- **Confidence**: Best-effort
- **Severity**: Warning
- **Applies to**: New JS/TS files in frontend directories
- **Requires**: `detected_patterns.frontend_js`

**Detection Procedure**:

1. Get the list of new JS/TS files in frontend directories from `git diff --name-status`
2. Load the expected init pattern from `detected_patterns.frontend_js` (e.g., exports `.init()`, uses `DOMContentLoaded`, uses module pattern)
3. Read the new file and check for the expected pattern:
   - If pattern is `init_method`: search for `export.*init\b` or `module.exports.*init`
   - If pattern is `dom_ready`: search for `DOMContentLoaded` or `\$\(document\).ready`
   - If pattern is `iife`: search for `\(function\s*\(` or `\(\(\) =>`
4. If the expected pattern is absent, flag it

**Violation Condition**: New JS/TS file does not use the established initialization pattern.

**Fix Template**: "JS file `{file}` should follow the `{pattern}` initialization pattern. See `documentation/style-guide.md`."

> **Note**: This is a best-effort check. Label findings as "Review Suggested."

---

## Integration Rules -- High Confidence

### INT-001: Accessing Module Internals

- **Category**: Integration
- **Confidence**: High
- **Severity**: Error (strict) | Warning
- **Applies to**: All source files
- **Requires**: Module boundary definitions from `documentation/integration-map.md`

**Detection Procedure**:

1. Load module boundaries from `documentation/integration-map.md`
2. Build a list of internal/private paths per module:
   ```
   module-a/internal/*, module-a/private/*, module-a/src/helpers/*
   ```
3. Get the list of changed files from `git diff --name-status`
4. For each changed file, extract all import/require statements (stack-specific):

| Stack | Import Pattern |
|-------|---------------|
| Node.js/TS | `import .* from ['"]`, `require(['"]` |
| Python | `from .* import`, `import .*` |
| Go | `import "`, `import (` |
| Java | `import .*;` |
| .NET | `using .*;` |
| PHP | `use .*;`, `require_once` |

5. For each import, check if the resolved path reaches into another module's internal directory
6. If it does, flag it

**Violation Condition**: Import resolves to another module's internal/private path instead of its public API.

**Fix Template**: "Import at `{file}:{line}` accesses `{module}` internals. Use the public API instead. See `documentation/integration-map.md`."

---

### INT-002: New Shared Resource Without Documentation

- **Category**: Integration
- **Confidence**: High
- **Severity**: Error (strict) | Warning
- **Applies to**: Files with database table references or cache key definitions
- **Requires**: `documentation/integration-map.md` shared resources table

**Detection Procedure**:

1. Load the shared resources table from `documentation/integration-map.md`
2. Get the list of changed files
3. For each changed file, search for new table name references using stack-specific patterns:

| Stack | Table Reference Patterns |
|-------|------------------------|
| SQL/ORM | `CREATE TABLE`, `ALTER TABLE`, `FROM [table]`, `JOIN [table]` |
| Node.js | `Model.define('table'`, `knex('table'` |
| Python/Django | `class Meta: db_table`, `objects.filter(` |
| PHP/Laravel | `\$table =`, `DB::table(` |

4. For each detected table name, check if it already exists in `integration-map.md`
5. If not, search for the same table name across all changed and existing files
6. If the table is referenced by files in two or more different modules, flag it

**Violation Condition**: A shared resource is used by multiple modules but is not documented in `integration-map.md`.

**Fix Template**: "Shared resource `{resource}` used by `{module_a}` and `{module_b}` is not documented. Update `documentation/integration-map.md`."

---

## Integration Rules -- Best Effort

### INT-010: Cross-Module Call Pattern Mismatch

- **Category**: Integration
- **Confidence**: Best-effort
- **Severity**: Warning
- **Applies to**: Cross-module function calls
- **Requires**: Integration patterns from `documentation/integration-map.md`

**Detection Procedure**:

1. Load documented integration patterns from `documentation/integration-map.md`
2. For each changed file, identify which module it belongs to
3. Extract all function calls that reference another module (import from external module + usage)
4. Compare the call pattern (sync/async, direct/event/message) against the documented pattern for that module pair
5. If the call pattern differs from the documented pattern, flag it

**Violation Condition**: Cross-module call does not match the documented integration pattern.

**Fix Template**: "Cross-module call at `{file}:{line}` doesn't match the documented pattern for `{module_a}` -> `{module_b}`. See `documentation/integration-map.md`."

> **Note**: This is a best-effort check. Label findings as "Review Suggested."

---

## Stack-Specific Rule Overrides

Additional rules that apply only to specific technology stacks. Load these alongside the general rules when the corresponding stack is detected.

| Stack | Rule ID | Rule Name | Detection |
|-------|---------|-----------|-----------|
| PHP/WordPress | WP-001 | Hook Registration | New `add_action`/`add_filter` without corresponding documentation in `integration-map.md` |
| PHP/WordPress | WP-002 | Direct Query | `\$wpdb->get_results` or `\$wpdb->query` outside Model classes |
| Python/Django | DJ-001 | Signal Registration | New `Signal.connect()` without documentation in `integration-map.md` |
| .NET | NET-001 | DI Registration | New service registered in DI container without interface |
| Java/Spring | SP-001 | Event Publishing | New `ApplicationEvent` without listener documentation in `integration-map.md` |
| Node.js | NJS-001 | Event Emitter | New `emit()` calls without documented event types in `integration-map.md` |

### Detection Patterns for Stack-Specific Rules

**WP-001**:
```regex
add_(action|filter)\s*\(\s*['"]([^'"]+)['"]
```
Check if captured hook name exists in `documentation/integration-map.md`.

**WP-002**:
```regex
\$wpdb->(get_results|get_var|get_row|get_col|query|prepare)\s*\(
```
Flag if file is not in a Model/Repository directory.

**DJ-001**:
```regex
\.connect\s*\(|Signal\(
```
Check if signal name is documented in `documentation/integration-map.md`.

**NET-001**:
```regex
services\.(AddScoped|AddTransient|AddSingleton)<([^>]+)>
```
Check that the registered type has a corresponding interface.

**SP-001**:
```regex
publishEvent\s*\(|ApplicationEvent
```
Check if event type is documented in `documentation/integration-map.md`.

**NJS-001**:
```regex
\.emit\s*\(\s*['"]([^'"]+)['"]
```
Check if event name is documented in `documentation/integration-map.md`.

---

## Consistency Check Execution Procedure

Step-by-step procedure called from SKILL.md step 3.4.5.

### Step 1: Load Context

Read the following files and extract required data:

| File | Data Extracted |
|------|---------------|
| `documentation/.docstate` | `detected_patterns`, `last_commit` |
| `documentation/config.json` | `consistency_check`, `style_guide`, `stack` |
| `documentation/capability-map.md` | Capability entries (if file exists) |
| `documentation/style-guide.md` | Token values, forbidden patterns (if file exists) |
| `documentation/integration-map.md` | Module boundaries, shared resources (if file exists) |

If a file does not exist, skip rules that depend on it.

### Step 2: Determine Applicable Rules

1. Get changed files:
   ```bash
   git diff --name-status [last_commit]..HEAD
   ```
2. For each changed file, determine its type (source, CSS, template, test, config)
3. Select rules whose **Applies to** field matches the file type
4. Filter out rules whose **Requires** dependencies are missing (file not found or pattern not detected)

### Step 3: Execute Rules

For each changed file and each applicable rule:

1. Run the detection procedure step by step
2. If a violation is found, record it:
   ```json
   {
     "file": "src/controllers/NewController.ts",
     "line": 42,
     "rule_id": "ARCH-001",
     "severity": "Error",
     "confidence": "High",
     "description": "Route definition outside expected directory",
     "suggestion": "New endpoint at `src/controllers/NewController.ts` should be in `src/routes/` per the project's routing pattern."
   }
   ```

### Step 4: Determine Severity

Apply severity based on `config.consistency_check.strict`:

| `strict` Value | High-confidence | Best-effort |
|----------------|-----------------|-------------|
| `true` | Error | Warning |
| `false` | Warning | Warning |

### Step 5: Generate Report

Create `documentation/.consistency-report.md`:

1. If violations found, use the consistency report template from `references/doc-templates.md`
2. If no violations found, write:
   ```markdown
   # Consistency Report

   **Status**: Pass
   **Date**: [ISO timestamp]
   **Commit Range**: [last_commit]..[current HEAD]

   No violations found.
   ```
3. Include summary counts at the top: `X errors, Y warnings`

### Step 6: Return Results

Return the violation list for inclusion in the PR description (SKILL.md step 4.3). Format for PR body:

```markdown
### Consistency Check

- **Errors**: X
- **Warnings**: Y

| Rule | File | Line | Description |
|------|------|------|-------------|
| ARCH-001 | `src/foo.ts` | 42 | Route outside expected directory |
```

---

## Updating Rules After Documentation Changes

When the consistency check detects that underlying patterns have changed (new Model classes, new directory conventions, renamed modules):

1. **Detect drift**: Compare `detected_patterns` in `.docstate` against current codebase structure
2. **Update `.docstate`**: Write updated `detected_patterns` with new globs, class lists, or directory paths
3. **Re-run applicable rules**: Execute rules that depend on the updated patterns using the new values
4. **Resolve stale violations**: Previous violations that no longer apply with the updated patterns should be removed from `.consistency-report.md`
5. **Log changes**: Note which patterns were updated in the report so reviewers can verify the drift was intentional
