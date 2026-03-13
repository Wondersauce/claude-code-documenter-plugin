#!/usr/bin/env bash
# SubagentStop hook: Auto-accumulate token usage from subagent completion.
# Appends token data to .ws-session/token-log.json when orchestrator is active.
#
# Reads subagent result from stdin.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/session-utils.sh"

# Only track when orchestrator is the active skill
if ! has_active_orchestrator; then
  exit 0
fi

# Read subagent output from stdin
INPUT=$(cat)

# Extract token counts if present
INPUT_TOKENS=$(echo "$INPUT" | grep -o '"input_tokens"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$')
OUTPUT_TOKENS=$(echo "$INPUT" | grep -o '"output_tokens"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$')

# Extract skill name if present
SKILL_NAME=$(echo "$INPUT" | grep -o '"skill"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

# Skip if no token data
if [ -z "$INPUT_TOKENS" ] && [ -z "$OUTPUT_TOKENS" ]; then
  exit 0
fi

INPUT_TOKENS="${INPUT_TOKENS:-0}"
OUTPUT_TOKENS="${OUTPUT_TOKENS:-0}"
SKILL_NAME="${SKILL_NAME:-unknown}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

TOKEN_LOG="${WS_SESSION_DIR}/token-log.json"

# Initialize if needed
if [ ! -f "$TOKEN_LOG" ]; then
  echo '{"entries":[]}' > "$TOKEN_LOG"
fi

# Append entry
TEMP_FILE=$(mktemp)
sed 's/\]}//' "$TOKEN_LOG" > "$TEMP_FILE"
if grep -q '"skill"' "$TEMP_FILE" 2>/dev/null; then
  echo "," >> "$TEMP_FILE"
fi
cat >> "$TEMP_FILE" << EOF
{"skill":"${SKILL_NAME}","input_tokens":${INPUT_TOKENS},"output_tokens":${OUTPUT_TOKENS},"timestamp":"${TIMESTAMP}"}
]}
EOF
mv "$TEMP_FILE" "$TOKEN_LOG"

exit 0
