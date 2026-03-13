#!/usr/bin/env bash
# PostToolUse hook: Auto-track file changes for ws-dev.
# Appends to .ws-session/file-changes.json when ws-dev is active.
#
# Reads tool_input from stdin (JSON with file_path field).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/session-utils.sh"

ACTIVE_SKILL=$(get_active_skill)

# Only track when ws-dev is the active skill
if [ "$ACTIVE_SKILL" != "dev" ]; then
  exit 0
fi

# Read the tool input from stdin
INPUT=$(cat)

# Extract the file path
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Normalize path
FILE_PATH="${FILE_PATH#./}"

# Skip session files and non-source files
case "$FILE_PATH" in
  .ws-session/*|.gitignore|.claude/*|CLAUDE.md)
    exit 0
    ;;
esac

# Detect tool name from environment or input
TOOL_NAME="${TOOL_NAME:-Write}"

# Determine action based on whether file existed before
CHANGES_FILE="${WS_SESSION_DIR}/file-changes.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Initialize the changes file if it doesn't exist
if [ ! -f "$CHANGES_FILE" ]; then
  echo '{"changes":[]}' > "$CHANGES_FILE"
fi

# Check if this file was already tracked (avoid duplicates for same file)
if grep -q "\"path\":\"${FILE_PATH}\"" "$CHANGES_FILE" 2>/dev/null; then
  # File already tracked — update timestamp (file was modified again)
  # For simplicity, we don't update in place; the latest entry wins at read time
  :
fi

# Append the change entry
# Use a temp file for atomic write
TEMP_FILE=$(mktemp)
# Remove the trailing ]} and append new entry
sed 's/\]}//' "$CHANGES_FILE" > "$TEMP_FILE"
# Check if there are existing entries (need comma separator)
if grep -q '"path"' "$TEMP_FILE" 2>/dev/null; then
  echo "," >> "$TEMP_FILE"
fi
cat >> "$TEMP_FILE" << EOF
{"path":"${FILE_PATH}","tool":"${TOOL_NAME}","timestamp":"${TIMESTAMP}"}
]}
EOF
mv "$TEMP_FILE" "$CHANGES_FILE"

exit 0
