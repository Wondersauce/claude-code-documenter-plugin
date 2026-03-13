#!/usr/bin/env bash
# Shared session utilities for ws-coding-workflows hooks.
# Sourced by hook scripts — not executed directly.

set -euo pipefail

WS_SESSION_DIR=".ws-session"

# Detect which ws skill is currently active by checking session files.
# Returns the skill name (orchestrator, planner, dev, verifier, documenter)
# or "none" if no active session.
get_active_skill() {
  local skill_files=("orchestrator" "planner" "debugger" "dev" "verifier" "documenter")
  for skill in "${skill_files[@]}"; do
    local file="${WS_SESSION_DIR}/${skill}.json"
    if [ -f "$file" ]; then
      local status
      status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$file" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
      if [ "$status" = "active" ] || [ "$status" = "paused" ]; then
        echo "$skill"
        return 0
      fi
    fi
  done
  echo "none"
  return 0
}

# Check if any ws session is active (any skill).
has_active_session() {
  local skill
  skill=$(get_active_skill)
  [ "$skill" != "none" ]
}

# Check if orchestrator session is active specifically.
has_active_orchestrator() {
  local file="${WS_SESSION_DIR}/orchestrator.json"
  if [ -f "$file" ]; then
    local status
    status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$file" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    [ "$status" = "active" ] || [ "$status" = "paused" ]
  else
    return 1
  fi
}

# Read a JSON string field from a file (basic grep-based, no jq dependency).
read_json_field() {
  local file="$1"
  local field="$2"
  grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/'
}
