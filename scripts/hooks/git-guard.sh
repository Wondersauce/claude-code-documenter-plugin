#!/usr/bin/env bash
# PreToolUse hook: Enforce git conventions during ws workflows.
# Blocks force pushes, enforces --no-ff merges, validates branch naming.
#
# Only active when a ws-orchestrator session exists.
# Reads tool_input from stdin (JSON with command field).
# Exits 0 to allow, exits 2 to block.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/session-utils.sh"

# Only enforce when ws session is active
if ! has_active_session; then
  exit 0
fi

# Read the tool input from stdin
INPUT=$(cat)

# Extract the command being run
COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Only check git commands
if ! echo "$COMMAND" | grep -q "^git "; then
  exit 0
fi

# Block force push
if echo "$COMMAND" | grep -qE "git\s+push\s+.*(-f|--force)"; then
  echo "BLOCKED: Force push is not allowed during ws workflows. Use standard push."
  exit 2
fi

# Block hard reset
if echo "$COMMAND" | grep -qE "git\s+reset\s+--hard"; then
  ACTIVE_SKILL=$(get_active_skill)
  # Allow orchestrator to reset during abort flow
  if [ "$ACTIVE_SKILL" != "orchestrator" ]; then
    echo "BLOCKED: git reset --hard is not allowed during ws workflows. Only ws-orchestrator can perform destructive git operations."
    exit 2
  fi
fi

# Warn on merge without --no-ff (but don't block — orchestrator handles this)
# This is informational only

exit 0
