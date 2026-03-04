---
name: ws-codebase-documenter
description: Generate and maintain comprehensive codebase documentation optimized for AI consumption, including development playbooks, capability maps, style guides, integration maps, and consistency checking. Optionally syncs to a Docusaurus site. Use when asked to document a codebase, generate API documentation, create docs for AI agents, maintain documentation after code changes, or sync docs to Docusaurus. Supports Node.js/TypeScript, Python, Go, Rust, .NET, Java, and PHP projects.
argument-hint: "[bootstrap|update|regenerate <doc-type>]"
---

# Codebase Documenter

Generate structured documentation designed for consumption by AI assistants and code agents working on dependent projects.

## Workflow

### 1. Determine Mode

Check if `documentation/config.json` exists:
- **Does not exist**: Bootstrap Mode (first run)
- **Exists**: Check the user's argument:
  - `regenerate [doc-type]`: Regenerate Mode (targeted re-generation)
  - Otherwise: Incremental Mode (subsequent runs)

### 2. Bootstrap Mode

Execute when `documentation/config.json` is absent.

#### 2.1 Detect Stack

Check for these files in order:

| File | Stack |
|------|-------|
| `package.json` | nodejs |
| `requirements.txt`, `pyproject.toml`, `setup.py` | python |
| `go.mod` | go |
| `Cargo.toml` | rust |
| `*.csproj`, `*.sln` | dotnet |
| `pom.xml`, `build.gradle` | java |
| `composer.json` | php |

#### 2.2 Create Config

Write a single `documentation/config.json` file containing all fields:

```json
{
  "stack": "[detected-stack]",
  "exclude": [
    "**/*.test.*",
    "**/*.spec.*",
    "**/test/**",
    "**/tests/**",
    "**/__tests__/**",
    "**/node_modules/**",
    "**/vendor/**",
    "**/dist/**",
    "**/build/**",
    "**/target/**"
  ],
  "include_inline_examples": true,
  "include_architecture_diagrams": true,
  "docusaurus": null,
  "frontend": {
    "enabled": true,
    "css_paths": [],
    "js_paths": [],
    "token_files": [],
    "build_tool": null,
    "methodology": null
  },
  "playbook": {
    "enabled": true,
    "custom_procedures": []
  },
  "capability_map": {
    "enabled": true,
    "custom_categories": []
  },
  "style_guide": {
    "enabled": true,
    "forbidden_patterns": ["!important", "inline styles"],
    "custom_rules": []
  },
  "integration_map": {
    "enabled": true
  },
  "consistency_check": {
    "enabled": true,
    "strict": false
  },
  "claude_md": {
    "inject_rules": true,
    "max_rules": 25,
    "custom_rules": []
  }
}
```

If Docusaurus sync is requested, set the `docusaurus` field:

```json
{
  "docusaurus": {
    "repo": "git@github.com:org/docs-site.git",
    "branch": "main",
    "docs_path": "docs/api",
    "sidebar_label": "API Reference"
  }
}
```

All fields from `frontend` onward are optional — existing `config.json` files without these fields use the defaults shown above.

#### 2.2b Backfill Config

After the scan (step 2.4) completes, update `documentation/config.json` a second time with auto-detected values:
- Set `frontend.css_paths` to detected CSS/SCSS directory paths
- Set `frontend.js_paths` to detected JS/TS frontend directory paths
- Set `frontend.token_files` to detected design token file paths
- Set `frontend.build_tool` to detected build tool name
- Set `frontend.methodology` to detected CSS methodology

This second write backfills detected values so the user can review and override them in subsequent runs.

#### 2.3 Read Stack Reference

Load the appropriate reference file:
- `references/stacks/[stack].md`

This provides patterns for identifying public/private API, documentation comments, error handling, and project structure conventions.

#### 2.4 Scan Codebase

1. List all source files (respecting `exclude` patterns)
2. Identify public API surface using stack-specific patterns
3. Categorize items: functions, types, errors, features
4. Extract documentation comments
5. Map relationships between items
6. If `config.frontend.enabled` is `true`: scan frontend assets following the procedures in `references/frontend-detection.md`. This detects CSS/SCSS organization, methodology, design tokens, breakpoints, JS initialization patterns, build tools, and anti-patterns.
7. Track cross-module function calls using patterns from the "Cross-Module Patterns" section in `references/stacks/[stack].md`. Record: calling module, called function/method, file path, and data passed.
8. For each design pattern detected in step 5, extract concrete details for playbook generation: file path globs, base classes/interfaces, directory conventions, required method signatures.
9. While scanning, build the capability map incrementally — classify each public function/type into a functional domain category as it is discovered. Do NOT defer this to a second pass.

#### 2.5 Generate Documentation

Read `references/doc-templates.md` for exact formats.

Create directory structure:
```
documentation/
├── config.json
├── .docstate
├── overview.md
├── architecture.md
├── playbook.md
├── capability-map.md
├── style-guide.md
├── integration-map.md
├── public/
│   ├── _index.md
│   ├── features/
│   ├── api/
│   ├── functions/
│   ├── types/
│   └── errors/
└── private/
    ├── _index.md
    ├── functions/
    ├── types/
    └── utils/
```

Generate files:
1. `overview.md` - Project purpose, entry points, quick start
2. `architecture.md` - Component diagrams, data flow, design patterns
3. Function docs - One file per function in appropriate directory
4. Type docs - One file per type
5. Error docs - Error hierarchy and patterns
6. Index files - `_index.md` in each directory
7. `playbook.md` — Read template 11 from `references/doc-templates.md`. For each design pattern extracted in step 2.4 (item 8), generate a numbered step-by-step procedure. Include checklists and common mistakes. Only generated when `config.playbook.enabled` is `true`.
8. `capability-map.md` — Read template 12 from `references/doc-templates.md`. Use the domain classifications built incrementally during step 2.4 (item 9). Organize into task-oriented categories. Only generated when `config.capability_map.enabled` is `true`.
9. `style-guide.md` — Read template 13 from `references/doc-templates.md`. Use frontend scan results from step 2.4 (item 6). Only generated when `config.style_guide.enabled` is `true` AND frontend assets were detected.
10. `integration-map.md` — Read template 14 from `references/doc-templates.md`. Use cross-module data from step 2.4 (item 7). Only generated when `config.integration_map.enabled` is `true`.

#### 2.6 Update Claude Code Instructions

Create or update `CLAUDE.md` in the project root to reference the documentation. If the file exists, append to it; otherwise create it.

**Step A**: If `config.claude_md.inject_rules` is `true` (default), add the Project Rules section:

```markdown
## Project Rules

These rules MUST be followed when modifying this codebase:

### Architecture
- [Generated rules from architecture.md and playbook.md]

### Data Access
- [Generated rules about ORM/Model usage patterns]

### Frontend
- [Generated rules from style-guide.md]

### Before Creating New Code
- Check `documentation/capability-map.md` before creating any new utility, helper, or shared function
- Check `documentation/public/_index.md` before creating any new public API
- Follow the step-by-step procedures in `documentation/playbook.md` for common tasks

### Documentation
- After adding new public functions, types, or components, update the relevant documentation files
- After adding new cross-module integrations, update `documentation/integration-map.md`
```

Extract project-specific rules to populate the subsections above (max `config.claude_md.max_rules`, default 25). Priority order when candidates exceed the limit:
1. `config.claude_md.custom_rules` — user-defined rules, always included first
2. Architecture rules from `architecture.md` and `playbook.md`
3. Data access rules from detected Model/Repository patterns
4. Frontend rules from `style-guide.md` (when applicable)
5. Documentation maintenance rules

If `config.claude_md.inject_rules` is `false`, skip Step A entirely.

**Step B**: Always add the Codebase Documentation section:

```markdown
## Codebase Documentation

This project has AI-optimized documentation in the `documentation/` folder.

Before making changes to this codebase:
1. Read `documentation/overview.md` for project purpose and entry points
2. Read `documentation/architecture.md` for system design and data flow
3. Read `documentation/playbook.md` for how to add new features
4. Check `documentation/capability-map.md` for existing utilities and helpers
5. Check `documentation/style-guide.md` for frontend conventions
6. Check `documentation/public/_index.md` for the public API surface

When modifying existing code:
- Check the relevant function/type doc in `documentation/public/` or `documentation/private/`
- Note any error handling patterns in `documentation/public/errors/`

When adding new public APIs:
- Follow patterns documented in `documentation/playbook.md`
- Ensure consistency with existing APIs in `documentation/public/`
- Update `documentation/capability-map.md` with the new capability
```

#### 2.7 Write State

Create `documentation/.docstate`:
```json
{
  "last_commit": "[current HEAD SHA]",
  "last_run": "[ISO timestamp]",
  "docusaurus_last_sync": null,
  "docusaurus_synced_files": [],
  "consistency_last_check": null,
  "consistency_violations": 0,
  "generated_docs": [
    "overview.md",
    "architecture.md",
    "playbook.md",
    "capability-map.md",
    "style-guide.md",
    "integration-map.md"
  ],
  "detected_patterns": {
    "rest_endpoint": {
      "description": "Router → Controller → Model",
      "glob": "src/controllers/*.php",
      "base_class": "BaseController",
      "required_methods": ["handle", "validate"]
    },
    "data_access": {
      "description": "Model static methods with caching",
      "glob": "src/models/*.php",
      "base_class": "BaseModel",
      "required_methods": ["save", "to_array", "get_by"]
    },
    "frontend_css": {
      "description": "Component SCSS files",
      "glob": "src/css/blocks/*.scss"
    },
    "frontend_js": {
      "description": "Block entry points with .init()",
      "glob": "src/js/blocks/*.js"
    }
  },
  "frontend_stats": {
    "important_count": 0,
    "inline_style_count": 0,
    "token_count": 0,
    "breakpoint_count": 0
  }
}
```

Only include `detected_patterns` entries for patterns that were actually detected. `generated_docs` lists only the doc files that were actually generated (based on config flags). `frontend_stats` is only included when `config.frontend.enabled` is `true`.

Get current HEAD:
```bash
git rev-parse HEAD
```

### 3. Incremental Mode

Execute when `documentation/config.json` exists.

#### 3.1 Load State

Read `documentation/config.json` and `documentation/.docstate`.

#### 3.2 Get Changes

```bash
git diff --name-status [last_commit]..HEAD
```

Filter to source files only (exclude test files, config, etc).

#### 3.3 Analyze Changes

For each changed file:

1. Get the diff:
   ```bash
   git diff [last_commit]..HEAD -- [file]
   ```

2. Identify semantic changes:
   - New functions/types/classes added
   - Signatures modified (parameters, return types)
   - Items removed or deprecated
   - Error handling changes
   - Documentation comment updates

#### 3.4 Update Documentation

For each semantic change:

| Change Type | Action |
|-------------|--------|
| New item | Create new doc file |
| Modified signature | Update existing doc |
| Removed item | Mark deprecated or delete |
| New error | Add to error docs |

Also update:
- Relevant `_index.md` files
- `architecture.md` if structure changed
- Cross-references in related docs

Also update prescriptive documents when relevant changes are detected:

| Change Type | Document to Update |
|-------------|-------------------|
| New design pattern or pattern change | `playbook.md` — add or update procedure |
| New public function/type/helper | `capability-map.md` — add to relevant category |
| New frontend files or convention change | `style-guide.md` — update rules and tokens |
| New cross-module call or shared resource | `integration-map.md` — add integration pattern |

#### 3.4.5 Consistency Check

Skip if `config.consistency_check.enabled` is `false`.

1. Load `references/consistency-rules.md` for rule definitions and the execution procedure
2. Load `detected_patterns` from `documentation/.docstate`
3. For each changed file from step 3.2, run applicable consistency rules following the execution procedure in `references/consistency-rules.md`
4. If violations are found, generate `documentation/.consistency-report.md` using template 15 from `references/doc-templates.md`
5. Include consistency results in the PR description (step 4.3)

Severity is determined by `config.consistency_check.strict`:
- `strict: true` — High-confidence violations are Errors, best-effort findings are Warnings
- `strict: false` — All findings are Warnings

#### 3.5 Verify Claude Code Instructions

Check that `CLAUDE.md` contains both:
1. The "Codebase Documentation" reference section (from step 2.6)
2. The "Project Rules" section (from step 2.6), if `config.claude_md.inject_rules` is `true`

If the documentation reference section is missing, add it using the template from step 2.6.

If rules have changed (because underlying documentation was updated in step 3.4), regenerate the rules section using the priority order from step 2.6 and update CLAUDE.md.

#### 3.6 Update State

Update `documentation/.docstate` with new HEAD and timestamp.

### 3b. Regenerate Mode

Execute when user runs with `regenerate [doc-type]`.

Valid doc-types: `playbook`, `capability-map`, `style-guide`, `integration-map`, `overview`, `architecture`, `consistency-report`, `all`

#### 3b.1 Determine Scan Scope

Each doc type requires a different scan scope:

| Doc Type | Required Scan Steps |
|----------|-------------------|
| `playbook` | Pattern detection (step 2.4, items 5, 8) |
| `capability-map` | Full API scan (step 2.4, items 1-5, 9) |
| `style-guide` | Frontend scan only (step 2.4, item 6) |
| `integration-map` | Cross-module scan (step 2.4, item 7) |
| `overview` | Basic scan (step 2.4, items 1-3) |
| `architecture` | Full scan (step 2.4, items 1-5) |
| `consistency-report` | No scan — run consistency check (step 3.4.5) against current HEAD using existing `.docstate` patterns |
| `all` | Full scan (all of step 2.4) |

#### 3b.2 Load Config and State

Read `documentation/config.json` and `documentation/.docstate`. Load the stack reference file.

#### 3b.3 Execute Targeted Scan

Run only the scan steps required by the doc type (per the table above).

#### 3b.4 Regenerate Document

Regenerate the specified document file using the corresponding template from `references/doc-templates.md`.

#### 3b.5 Update State

Update `documentation/.docstate`:
- Set `last_run` to current timestamp
- Update `detected_patterns` if the scan detected changes
- Update `frontend_stats` if frontend scan was run
- Do NOT update `last_commit` — regeneration does not advance the incremental baseline

### 4. Create PR

#### 4.1 Branch Naming

Format: `docs/auto-update-YYYY-MM-DD-HH:MM`

If branch exists, append `-2`, `-3`, etc.

```bash
BRANCH="docs/auto-update-$(date +%Y-%m-%d-%H:%M)"
git checkout -b "$BRANCH"
```

#### 4.2 Commit Changes

```bash
git add documentation/
git commit -m "docs: update documentation for [commit range]"
```

#### 4.3 Push and Create PR

```bash
git push -u origin "$BRANCH"
```

Create PR with description summarizing changes (see PR Description template in `references/doc-templates.md`).

### 5. Docusaurus Sync (Optional)

Execute only if `config.docusaurus` is configured. See `references/docusaurus.md` for detailed patterns.

#### 5.1 Clone/Update Docusaurus Repo

```bash
DOCS_REPO="[config.docusaurus.repo]"
DOCS_BRANCH="[config.docusaurus.branch]"
DOCS_PATH="[config.docusaurus.docs_path]"

# Clone to temp directory if not exists
if [ ! -d ".docusaurus-sync" ]; then
  git clone --depth 1 -b "$DOCS_BRANCH" "$DOCS_REPO" .docusaurus-sync
else
  cd .docusaurus-sync && git pull && cd ..
fi
```

#### 5.2 Transform Documentation

For each markdown file in `documentation/`:

1. Add Docusaurus frontmatter:
   ```yaml
   ---
   id: [filename-without-extension]
   title: [extracted-from-h1]
   sidebar_label: [short-title]
   sidebar_position: [order]
   ---
   ```

2. Convert internal links from `../types/Foo.md` to Docusaurus paths

3. Copy to `.docusaurus-sync/[docs_path]/`

#### 5.3 Generate Sidebar

Create or update `.docusaurus-sync/[docs_path]/_category_.json` for each directory:

```json
{
  "label": "[directory-name-titlecased]",
  "position": [order],
  "collapsed": false
}
```

Generate `sidebars.js` entry if needed (see `references/docusaurus.md`).

#### 5.4 Commit and Push to Docusaurus Repo

```bash
cd .docusaurus-sync
git add .
git commit -m "docs: sync from [source-repo] @ [commit-sha]"
git push origin "$DOCS_BRANCH"
```

Or create a PR in the Docusaurus repo if preferred.

#### 5.5 Cleanup

```bash
rm -rf .docusaurus-sync
```

## Documentation Standards

### AI Optimization

Documentation must be optimized for AI consumption:

1. **Structured data over prose** - Use tables for parameters, errors, options
2. **Explicit types** - Always include full type signatures
3. **Complete examples** - Show imports, setup, and usage
4. **Error recovery** - Document how to handle each error
5. **Cross-references** - Link to related functions and types
6. **No ambiguity** - Specify defaults, constraints, edge cases

### Public vs Private

**Public** (`documentation/public/`):
- Exported functions, classes, types
- Items intended for external use
- API surface for dependent projects

**Private** (`documentation/private/`):
- Internal implementation details
- Helper functions
- Useful for understanding internals but not for direct use

### When to Document Private Items

Document private items when:
- They're complex and non-obvious
- They're frequently modified
- Understanding them helps debug issues
- They contain important business logic

Skip documenting:
- Trivial helpers (less than 5 lines)
- Generated code
- Boilerplate

## Error Handling

If documentation generation fails:
1. Do not commit partial changes
2. Log the error
3. Exit with non-zero status

Common issues:
- Cannot detect stack: Ask user to set `stack` in config.json
- Cannot parse source files: Skip unparseable files, continue with others
- Git operations fail: Ensure clean working directory
- Reference file missing: See the fallback column in the Reference Files table below

## Reference Files

Load these as needed. If a file cannot be read (missing, corrupted install, partial update), follow the fallback behavior:

| File | When to Load | If Missing |
|------|--------------|------------|
| `references/stacks/[stack].md` | After detecting or reading stack | **Fail** — cannot generate accurate docs without stack-specific rules. Log: `"Missing reference file for stack '{stack}'. Reinstall the plugin."` Stop. |
| `references/doc-templates.md` | When generating any documentation | **Fail** — templates are required for all output. Log: `"Missing doc-templates.md. Reinstall the plugin."` Stop. |
| `references/docusaurus.md` | When `config.docusaurus` is configured | **Skip feature** — skip Docusaurus sync. Log: `"Missing docusaurus.md. Skipping Docusaurus sync."` |
| `references/frontend-detection.md` | During frontend scan (step 2.4, item 6) | **Skip feature** — set all frontend results to empty/null, set `config.frontend.enabled` to `false`. Log: `"Missing frontend-detection.md. Skipping frontend scan."` |
| `references/consistency-rules.md` | During consistency check (step 3.4.5) | **Skip feature** — skip consistency checking entirely, omit the Consistency Check section from the PR description. Log: `"Missing consistency-rules.md. Skipping consistency checks."` |
