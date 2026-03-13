#!/usr/bin/env bash
# PreCompact hook: Snapshot session state before context compaction.
# Creates timestamped copies in .ws-session/snapshots/ as a safety net.

set -euo pipefail

WS_SESSION_DIR=".ws-session"
SNAPSHOT_DIR="${WS_SESSION_DIR}/snapshots"

# Only snapshot if session directory exists
if [ ! -d "$WS_SESSION_DIR" ]; then
  exit 0
fi

# Check if there are any session files to snapshot
SESSION_FILES=$(find "$WS_SESSION_DIR" -maxdepth 1 -name "*.json" 2>/dev/null)
if [ -z "$SESSION_FILES" ]; then
  exit 0
fi

TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
DEST="${SNAPSHOT_DIR}/${TIMESTAMP}"

mkdir -p "$DEST"

# Copy all session JSON files (not subdirectories)
for file in ${WS_SESSION_DIR}/*.json; do
  if [ -f "$file" ]; then
    cp "$file" "$DEST/"
  fi
done

# Keep only last 5 snapshots to prevent unbounded growth
SNAPSHOTS=$(ls -1d "${SNAPSHOT_DIR}/"*/ 2>/dev/null || true)
if [ -n "$SNAPSHOTS" ]; then
  COUNT=0
  echo "$SNAPSHOTS" | sort -r | while IFS= read -r dir; do
    COUNT=$((COUNT + 1))
    if [ $COUNT -gt 5 ]; then
      rm -rf "$dir"
    fi
  done
fi

exit 0
