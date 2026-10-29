#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$CURRENT_DIR/scripts"

mkdir -p "$HOME/.tmux-notifications"

get_option() {
    local value
    value=$(tmux show-option -gqv "$1" 2>/dev/null)
    echo "${value:-$2}"
}

key_next=$(get_option "@claude-notif-key-next" "n")
key_picker=$(get_option "@claude-notif-key-picker" "S")
key_log=$(get_option "@claude-notif-key-log" "")
key_toggle=$(get_option "@claude-notif-key-toggle" "")

status_bg=$(get_option "@claude-notif-status-bg" "default")
enable_status=$(get_option "@claude-notif-status-line" "on")

tmux set-hook -g client-session-changed "run-shell '$SCRIPTS_DIR/clear-notification.sh #{session_name} #{pane_current_path} #{pane_id}'"
tmux set-hook -g client-focus-in "run-shell '$SCRIPTS_DIR/clear-notification.sh #{session_name} #{pane_current_path} #{pane_id}'"
tmux set-hook -g pane-focus-in "run-shell '$SCRIPTS_DIR/clear-notification.sh #{session_name} #{pane_current_path} #{pane_id}'"

tmux bind-key "$key_next" run-shell "$SCRIPTS_DIR/next-notification.sh"
tmux bind-key "$key_picker" display-popup -w 60% -h 60% -E "$SCRIPTS_DIR/notification-picker.sh"
[ -n "$key_log" ] && tmux bind-key "$key_log" display-popup -w 80% -h 60% -E "$SCRIPTS_DIR/log-viewer.sh"
[ -n "$key_toggle" ] && tmux bind-key "$key_toggle" if-shell '[ "$(tmux show -gv status)" = "2" ]' 'set -g status on' 'set -g status 2'

if [ "$enable_status" = "on" ]; then
    tmux set -g status 2
    tmux set -g status-format[1] "#[align=left,bg=${status_bg}]#($SCRIPTS_DIR/notification-reader.sh)"
fi
