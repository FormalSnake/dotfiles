#!/usr/bin/env bash

HOOK_EVENT="$1"
LOG_FILE="$HOME/.claude/notifications.log"
TIMESTAMP=$(date '+%H:%M:%S')

# Read JSON from stdin
if [ ! -t 0 ]; then
    JSON_DATA=$(cat)
fi

# Extract project name
if [ -n "$JSON_DATA" ]; then
    CWD=$(echo "$JSON_DATA" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*: *"\([^"]*\)".*/\1/')
    PROJECT_NAME=$(basename "${CWD:-unknown}")
    PARENT_DIR=$(basename "$(dirname "$CWD")" 2>/dev/null)
    if [[ "$PARENT_DIR" == *.git ]]; then
        DISPLAY_NAME="${PARENT_DIR%.git}/$PROJECT_NAME"
    else
        DISPLAY_NAME="$PROJECT_NAME"
    fi
else
    PROJECT_NAME="unknown"
    DISPLAY_NAME="unknown"
fi

# Extract Claude session title from tmux pane_title (format: "✳ Session Name")
SESSION_TITLE=$(tmux display-message -t "$TMUX_PANE" -p '#{pane_title}' 2>/dev/null | sed 's/^[^a-zA-Z0-9]* *//')
[[ "$SESSION_TITLE" == "Claude Code" ]] && SESSION_TITLE=""

parse_json() {
    echo "$JSON_DATA" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed 's/.*: *"\([^"]*\)".*/\1/'
}

NOTIF_DIR="$HOME/.claude/.notifications"
mkdir -p "$NOTIF_DIR"
PANE_SAFE="${TMUX_PANE//%/}"
NOTIF_KEY="${PROJECT_NAME}__${PANE_SAFE}"

get_option() {
    tmux show-option -gqv "$1" 2>/dev/null
}

NOTIF_FG=$(get_option "@claude-notif-fg")
NOTIF_FG="${NOTIF_FG:-#c8d3f5}"
ALERT_FG=$(get_option "@claude-notif-alert-fg")
ALERT_FG="${ALERT_FG:-yellow}"
ALERT_STYLE=$(get_option "@claude-notif-alert-style")
ALERT_STYLE="${ALERT_STYLE:-bold}"

is_user_watching() {
    tmux list-clients -F '#{pane_id}' 2>/dev/null | grep -q "^${TMUX_PANE}$"
}

tmux_alert() {
    local msg="$1"
    local label="$DISPLAY_NAME"
    [ -n "$SESSION_TITLE" ] && label="$DISPLAY_NAME ($SESSION_TITLE)"

    if is_user_watching; then
        return 0
    fi

    echo "#[fg=${NOTIF_FG}][$TIMESTAMP] $label: #[fg=${ALERT_FG},${ALERT_STYLE}]$msg #[default]" > "$NOTIF_DIR/$NOTIF_KEY"
    echo "${TMUX_PANE}" > "$NOTIF_DIR/.pane_$NOTIF_KEY"
    tmux refresh-client -S 2>/dev/null
}

log_event() {
    local icon="$1"
    local msg="$2"
    local label="$DISPLAY_NAME"
    if [ -n "$SESSION_TITLE" ]; then
        label="$DISPLAY_NAME ($SESSION_TITLE)"
    fi
    echo "[$TIMESTAMP] $icon $label: $msg" >> "$LOG_FILE"
}

tmux_clear_alert() {
    rm -f "$NOTIF_DIR/$NOTIF_KEY" "$NOTIF_DIR/.pane_$NOTIF_KEY"
    tmux refresh-client -S 2>/dev/null
}

case "$HOOK_EVENT" in
    "Stop")
        log_event "done" "Agent has finished"
        tmux_alert "Agent has finished"
        ;;
    "Notification")
        MESSAGE=$(parse_json "message")
        MESSAGE=${MESSAGE:-"Needs attention"}
        MESSAGE=${MESSAGE//Claude/Agent}
        log_event "" "$MESSAGE"
        tmux_alert "$MESSAGE"
        ;;
    "UserPromptSubmit")
        tmux_clear_alert
        ;;
esac

exit 0
