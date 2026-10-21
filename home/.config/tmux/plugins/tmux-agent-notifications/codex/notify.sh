#!/bin/bash

# Codex CLI notification hook
# Receives JSON payload as first argument

JSON_DATA="$1"

if [ -n "$JSON_DATA" ]; then
    TYPE=$(echo "$JSON_DATA" | grep -o '"type"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*: *"\([^"]*\)".*/\1/')
    STATUS=$(echo "$JSON_DATA" | grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*: *"\([^"]*\)".*/\1/')
    CWD=$(echo "$JSON_DATA" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*: *"\([^"]*\)".*/\1/')
else
    TYPE="unknown"
    STATUS="unknown"
    CWD=$(pwd 2>/dev/null)
fi

NOTIFY_SOURCE="Codex"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "$SCRIPT_DIR/tmux-notify-lib.sh"

DISPLAY_NAME=$(resolve_project_name "$CWD")

case "$TYPE" in
    "agent-turn-complete")
        log_event "done" "Task finished" "$DISPLAY_NAME"
        tmux_alert "Task finished" "$DISPLAY_NAME"
        ;;
    "approval-request"|"input-required")
        log_event "" "Needs your approval" "$DISPLAY_NAME"
        tmux_alert "Needs your approval" "$DISPLAY_NAME"
        ;;
    *)
        case "$STATUS" in
            "success"|"completed")
                log_event "done" "Task completed" "$DISPLAY_NAME"
                tmux_alert "Task completed" "$DISPLAY_NAME"
                ;;
            "error"|"failed")
                log_event "err" "Task failed" "$DISPLAY_NAME"
                tmux_alert "Task failed" "$DISPLAY_NAME"
                ;;
            *)
                log_event "" "Needs attention" "$DISPLAY_NAME"
                tmux_alert "Needs attention" "$DISPLAY_NAME"
                ;;
        esac
        ;;
esac

exit 0
