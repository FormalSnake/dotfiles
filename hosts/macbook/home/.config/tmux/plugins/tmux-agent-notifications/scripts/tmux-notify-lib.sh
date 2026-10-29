#!/usr/bin/env bash
# Unified tmux notification library
# Sourced by tool-specific hooks (Claude Code, Codex, etc.)
#
# Required before sourcing:
#   NOTIFY_SOURCE  - tool label (e.g. "Claude", "Codex")
#   TMUX_PANE      - set automatically by tmux
#
# Optional before sourcing:
#   NOTIFY_CWD     - project directory (auto-detected from JSON if not set)
#   NOTIFY_LOG     - log file path (defaults to ~/.tmux-notifications/events.log)

NOTIF_DIR="$HOME/.tmux-notifications"
mkdir -p "$NOTIF_DIR"

NOTIFY_SOURCE="${NOTIFY_SOURCE:-Agent}"
NOTIFY_LOG="${NOTIFY_LOG:-$NOTIF_DIR/events.log}"
TIMESTAMP=$(date '+%H:%M:%S')

resolve_project_name() {
    local cwd="$1"
    local project parent
    project=$(basename "${cwd:-unknown}")
    parent=$(basename "$(dirname "$cwd")" 2>/dev/null)
    if [[ "$parent" == *.git ]]; then
        echo "${parent%.git}/$project"
    else
        echo "$project"
    fi
}

_notif_get_option() {
    tmux show-option -gqv "$1" 2>/dev/null
}

NOTIF_FG=$(_notif_get_option "@claude-notif-fg")
NOTIF_FG="${NOTIF_FG:-#c8d3f5}"
ALERT_FG=$(_notif_get_option "@claude-notif-alert-fg")
ALERT_FG="${ALERT_FG:-yellow}"
ALERT_STYLE=$(_notif_get_option "@claude-notif-alert-style")
ALERT_STYLE="${ALERT_STYLE:-bold}"

_notif_pane_safe="${TMUX_PANE//%/}"

is_user_watching() {
    local now
    now=$(date +%s)
    while IFS=$'\t' read -r flags activity pane_id; do
        [ "$pane_id" != "$TMUX_PANE" ] && continue
        [[ "$flags" != *focused* ]] && continue
        [ $((now - activity)) -lt 2 ] && return 0
    done < <(tmux list-clients -F '#{client_flags}	#{client_activity}	#{pane_id}' 2>/dev/null)
    return 1
}

refresh_all_clients() {
    tmux list-clients -F '#{client_name}' 2>/dev/null | while read -r c; do
        tmux refresh-client -S -t "$c" 2>/dev/null
    done
}

tmux_alert() {
    local msg="$1"
    local display_name="$2"
    local session_title="$3"

    local label="$display_name"
    [ -n "$session_title" ] && label="$display_name ($session_title)"

    is_user_watching && return 0

    local notif_key="${display_name}__${_notif_pane_safe}"
    echo "#[fg=${NOTIF_FG}][$TIMESTAMP] ${NOTIFY_SOURCE}/${label}: #[fg=${ALERT_FG},${ALERT_STYLE}]$msg #[default]" > "$NOTIF_DIR/$notif_key"
    echo "${TMUX_PANE}" > "$NOTIF_DIR/.pane_$notif_key"
    refresh_all_clients
}

tmux_clear_alert() {
    local display_name="$1"
    local notif_key="${display_name}__${_notif_pane_safe}"
    rm -f "$NOTIF_DIR/$notif_key" "$NOTIF_DIR/.pane_$notif_key"
    refresh_all_clients
}

log_event() {
    local icon="$1"
    local msg="$2"
    local display_name="$3"
    local session_title="$4"
    local label="$display_name"
    [ -n "$session_title" ] && label="$display_name ($session_title)"
    echo "[$TIMESTAMP] $icon ${NOTIFY_SOURCE}/$label: $msg" >> "$NOTIFY_LOG"
}
