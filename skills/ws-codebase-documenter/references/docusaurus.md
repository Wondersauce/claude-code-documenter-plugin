# Docusaurus Integration Reference

Patterns for syncing generated documentation to a Docusaurus site.

## Table of Contents
1. [Directory Mapping](#directory-mapping)
2. [Frontmatter Generation](#frontmatter-generation)
3. [Sidebar Configuration](#sidebar-configuration)
4. [Link Transformation](#link-transformation)
5. [File Naming](#file-naming)

---

## Directory Mapping

Map the `documentation/` structure to Docusaurus `docs/` path:

| Source | Docusaurus Destination |
|--------|------------------------|
| `documentation/overview.md` | `[docs_path]/index.md` |
| `documentation/architecture.md` | `[docs_path]/architecture.md` |
| `documentation/playbook.md` | `[docs_path]/playbook.md` |
| `documentation/capability-map.md` | `[docs_path]/capability-map.md` |
| `documentation/style-guide.md` | `[docs_path]/style-guide.md` |
| `documentation/integration-map.md` | `[docs_path]/integration-map.md` |
| `documentation/public/` | `[docs_path]/public/` |
| `documentation/public/functions/` | `[docs_path]/public/functions/` |
| `documentation/public/types/` | `[docs_path]/public/types/` |
| `documentation/public/errors/` | `[docs_path]/public/errors/` |
| `documentation/public/features/` | `[docs_path]/public/features/` |
| `documentation/private/` | `[docs_path]/private/` |

The `_index.md` files become `index.md` in Docusaurus.

---

## Frontmatter Generation

Every markdown file needs Docusaurus frontmatter.

### Basic Frontmatter

```yaml
---
id: function-name
title: functionName
sidebar_label: functionName
sidebar_position: 1
---
```

### Extracting Values

| Field | Source |
|-------|--------|
| `id` | Filename without `.md` extension, kebab-cased |
| `title` | First H1 heading in the document |
| `sidebar_label` | Same as title, or shortened version if > 25 chars |
| `sidebar_position` | Alphabetical order within directory, or explicit from `_index.md` |

### Special Pages

**Overview (index.md)**:
```yaml
---
id: overview
title: Project Name
sidebar_label: Overview
sidebar_position: 1
slug: /
---
```

**Architecture**:
```yaml
---
id: architecture
title: Architecture
sidebar_label: Architecture
sidebar_position: 2
---
```

**Playbook**:
```yaml
---
id: playbook
title: Development Playbook
sidebar_label: Playbook
sidebar_position: 3
---
```

**Capability Map**:
```yaml
---
id: capability-map
title: Capability Map
sidebar_label: Capability Map
sidebar_position: 4
---
```

**Style Guide**:
```yaml
---
id: style-guide
title: Style Guide
sidebar_label: Style Guide
sidebar_position: 5
---
```

**Integration Map**:
```yaml
---
id: integration-map
title: Integration Map
sidebar_label: Integration Map
sidebar_position: 6
---
```

**Index files** (`_index.md` -> `index.md`):
```yaml
---
id: functions-index
title: Functions
sidebar_label: Functions
sidebar_position: 1
---
```

---

## Sidebar Configuration

### Category Files

Create `_category_.json` in each directory:

**Root level** (`[docs_path]/_category_.json`):
```json
{
  "label": "API Reference",
  "position": 1,
  "collapsed": false,
  "link": {
    "type": "doc",
    "id": "overview"
  }
}
```

**Public API** (`[docs_path]/public/_category_.json`):
```json
{
  "label": "Public API",
  "position": 7,
  "collapsed": false
}
```

**Functions** (`[docs_path]/public/functions/_category_.json`):
```json
{
  "label": "Functions",
  "position": 1,
  "collapsed": true,
  "link": {
    "type": "doc",
    "id": "public/functions/index"
  }
}
```

**Types** (`[docs_path]/public/types/_category_.json`):
```json
{
  "label": "Types",
  "position": 2,
  "collapsed": true
}
```

**Errors** (`[docs_path]/public/errors/_category_.json`):
```json
{
  "label": "Errors",
  "position": 3,
  "collapsed": true
}
```

**Private** (`[docs_path]/private/_category_.json`):
```json
{
  "label": "Internals",
  "position": 10,
  "collapsed": true,
  "collapsible": true
}
```

### Sidebar Position Order

| Directory | Position |
|-----------|----------|
| Root index | 1 |
| Architecture | 2 |
| Playbook | 3 |
| Capability Map | 4 |
| Style Guide | 5 |
| Integration Map | 6 |
| Public | 7 |
| Public/Functions | 7.1 |
| Public/Types | 7.2 |
| Public/Errors | 7.3 |
| Public/Features | 7.4 |
| Private | 10 |

Within each directory, items are ordered alphabetically unless `_index.md` specifies an order.

---

## Link Transformation

Convert internal markdown links to Docusaurus format.

### Relative Links

| Original | Docusaurus |
|----------|------------|
| `[Foo](../types/Foo.md)` | `[Foo](../types/foo)` |
| `[bar](./bar.md)` | `[bar](./bar)` |
| `[index](./_index.md)` | `[index](./index)` |

### Rules

1. Remove `.md` extension
2. Convert `_index.md` to `index`
3. Keep relative paths intact
4. Kebab-case filenames: `UserService.md` -> `user-service`

### Transformation Regex

```javascript
// Remove .md extension
content = content.replace(/\]\(([^)]+)\.md\)/g, ']($1)');

// Convert _index to index
content = content.replace(/\]\(([^)]*)_index\)/g, ']($1index)');
```

---

## File Naming

Docusaurus prefers kebab-case filenames.

### Conversion Rules

| Original | Docusaurus |
|----------|------------|
| `UserService.md` | `user-service.md` |
| `createUser.md` | `create-user.md` |
| `HTTPClient.md` | `http-client.md` |
| `_index.md` | `index.md` |

### ID Generation

The `id` in frontmatter should match the kebab-cased filename:

```yaml
# File: user-service.md
---
id: user-service
title: UserService
---
```

---

## Full Transformation Example

**Input** (`documentation/public/functions/createUser.md`):
```markdown
# createUser

Creates a new user.

## Related

- [User](../types/User.md)
- [ValidationError](../errors/ValidationError.md)
```

**Output** (`[docs_path]/public/functions/create-user.md`):
```markdown
---
id: create-user
title: createUser
sidebar_label: createUser
sidebar_position: 3
---

# createUser

Creates a new user.

## Related

- [User](../types/user)
- [ValidationError](../errors/validation-error)
```

---

## Incremental Sync

When running in incremental mode:

1. Only process changed files from the documentation update
2. Preserve existing Docusaurus files not managed by the sync
3. Update `_category_.json` only if new files added or removed
4. Track synced files in `documentation/.docstate`:

```json
{
  "last_commit": "abc123",
  "last_run": "2025-01-29T15:30:00Z",
  "docusaurus_synced": [
    "public/functions/create-user.md",
    "public/types/user.md"
  ]
}
```
