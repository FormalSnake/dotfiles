#!/usr/bin/env bash

HOOK_EVENT="$1"

if [ ! -t 0 ]; then
    JSON_DATA=$(cat)
fi

CWD=""
if [ -n "$JSON_DATA" ]; then
    CWD=$(echo "$JSON_DATA" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

NOTIFY_SOURCE="Claude"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tmux-notify-lib.sh"

DISPLAY_NAME=$(resolve_project_name "$CWD")

SESSION_TITLE=$(tmux display-message -t "$TMUX_PANE" -p '#{pane_title}' 2>/dev/null | sed 's/^[^a-zA-Z0-9]* *//')
[[ "$SESSION_TITLE" == "Claude Code" ]] && SESSION_TITLE=""

parse_json() {
    echo "$JSON_DATA" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed 's/.*: *"\([^"]*\)".*/\1/'
}

case "$HOOK_EVENT" in
    "Stop")
        log_event "done" "Agent has finished" "$DISPLAY_NAME" "$SESSION_TITLE"
        tmux_alert "Agent has finished" "$DISPLAY_NAME" "$SESSION_TITLE"
        ;;
    "Notification")
        MESSAGE=$(parse_json "message")
        MESSAGE=${MESSAGE:-"Needs attention"}
        MESSAGE=${MESSAGE//Claude/Agent}
        log_event "" "$MESSAGE" "$DISPLAY_NAME" "$SESSION_TITLE"
        tmux_alert "$MESSAGE" "$DISPLAY_NAME" "$SESSION_TITLE"
        ;;
    "PreToolUse")
        is_user_watching && tmux_clear_alert "$DISPLAY_NAME"
        ;;
    "UserPromptSubmit"|"SessionEnd")
        tmux_clear_alert "$DISPLAY_NAME"
        ;;
esac

exit 0
