# Codebase Documenter

A Claude Code plugin that generates and maintains comprehensive codebase documentation optimized for AI consumption.

## Installation

Inside Claude Code, run:

```
/plugin install Wondersauce/claude-code-documenter-plugin
```

## Usage

Once installed, ask Claude Code to document your codebase:

```
document this codebase
```

Or for incremental updates after code changes:

```
update the documentation
```

## What It Does

**Bootstrap mode** (first run):
- Detects your stack (Node.js, Python, Go, Rust, .NET, Java, PHP)
- Creates `documentation/config.json`
- Scans for public/private APIs
- Generates structured markdown docs
- Updates `CLAUDE.md` so Claude Code knows to use the docs

**Incremental mode** (subsequent runs):
- Analyzes git diff since last run
- Updates only changed functions/types
- Keeps docs in sync with code

## Output Structure

```
documentation/
├── config.json
├── .docstate
├── overview.md
├── architecture.md
├── public/
│   ├── _index.md
│   ├── functions/
│   ├── types/
│   └── errors/
└── private/
    ├── _index.md
    ├── functions/
    └── types/
```

## Docusaurus Sync (Optional)

To sync docs to a separate Docusaurus site, add to `documentation/config.json`:

```json
{
  "docusaurus": {
    "repo": "git@github.com:your-org/docs-site.git",
    "branch": "main",
    "docs_path": "docs/api",
    "sidebar_label": "API Reference"
  }
}
```

## Supported Stacks

| Stack | Detection |
|-------|-----------|
| Node.js/TypeScript | `package.json` |
| Python | `requirements.txt`, `pyproject.toml`, `setup.py` |
| Go | `go.mod` |
| Rust | `Cargo.toml` |
| .NET | `*.csproj`, `*.sln` |
| Java | `pom.xml`, `build.gradle` |
| PHP | `composer.json` |

## License

MIT
