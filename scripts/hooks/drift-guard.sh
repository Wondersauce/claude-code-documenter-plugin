#!/usr/bin/env bash
# PreToolUse hook: Enforce skill write boundaries.
# Blocks Write/Edit operations that violate the active skill's allowed targets.
#
# Reads tool_input from stdin (JSON with file_path field).
# Exits 0 to allow, exits 2 to block (with reason on stdout).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/session-utils.sh"

# Read the tool input from stdin
INPUT=$(cat)

# Extract the file path being written to
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

if [ -z "$FILE_PATH" ]; then
  # No file_path in input — allow (might be a different tool format)
  exit 0
fi

ACTIVE_SKILL=$(get_active_skill)

if [ "$ACTIVE_SKILL" = "none" ]; then
  # No active ws session — allow all writes
  exit 0
fi

# Normalize path (remove leading ./ if present)
FILE_PATH="${FILE_PATH#./}"

# Define allowed write targets per skill
case "$ACTIVE_SKILL" in
  orchestrator)
    # Orchestrator can write: session files, .gitignore, .claude/ settings, CLAUDE.md
    case "$FILE_PATH" in
      .ws-session/*|.gitignore|.claude/*|CLAUDE.md)
        exit 0
        ;;
      *)
        echo "BLOCKED: ws-orchestrator cannot write to source or documentation files. Route implementation to ws-dev via Task()."
        exit 2
        ;;
    esac
    ;;

  planner)
    # Planner can only write its own session file
    case "$FILE_PATH" in
      .ws-session/planner.json)
        exit 0
        ;;
      *)
        echo "BLOCKED: ws-planner cannot write files. It produces plans, not code."
        exit 2
        ;;
    esac
    ;;

  verifier)
    # Verifier can only write its own session file
    case "$FILE_PATH" in
      .ws-session/verifier.json)
        exit 0
        ;;
      *)
        echo "BLOCKED: ws-verifier cannot write or edit source code. It reads and judges only."
        exit 2
        ;;
    esac
    ;;

  dev)
    # Dev can write: source code, session files, documentation updates planned in task
    # Dev CANNOT write: plugin skill files, hook scripts
    case "$FILE_PATH" in
      .ws-session/*|scripts/hooks/*)
        # Session files: allow. Hook scripts: block.
        if [[ "$FILE_PATH" == scripts/hooks/* ]]; then
          echo "BLOCKED: ws-dev cannot modify hook scripts."
          exit 2
        fi
        exit 0
        ;;
      skills/*)
        echo "BLOCKED: ws-dev cannot modify plugin skill files."
        exit 2
        ;;
      *)
        # Allow all other writes (source code, config, docs updates per task)
        exit 0
        ;;
    esac
    ;;

  debugger)
    # Debugger can only write its own session file — it reads and diagnoses, never fixes
    case "$FILE_PATH" in
      .ws-session/debugger.json)
        exit 0
        ;;
      *)
        echo "BLOCKED: ws-debugger cannot write files. It investigates and diagnoses only."
        exit 2
        ;;
    esac
    ;;

  documenter)
    # Documenter can write: documentation files, session files, CLAUDE.md, config
    case "$FILE_PATH" in
      documentation/*|.ws-session/*|CLAUDE.md)
        exit 0
        ;;
      *)
        echo "BLOCKED: ws-codebase-documenter can only write to documentation/ and session files."
        exit 2
        ;;
    esac
    ;;

  *)
    # Unknown skill — allow (don't block on unexpected state)
    exit 0
    ;;
esac
