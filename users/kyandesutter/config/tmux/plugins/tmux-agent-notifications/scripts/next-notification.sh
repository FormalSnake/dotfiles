#!/usr/bin/env bash
DIR="$HOME/.claude/.notifications"
[ ! -d "$DIR" ] && exit 0

# Oldest notification first (waiting longest), skip hidden files
TARGET=$(ls -tr "$DIR" 2>/dev/null | grep -v '^\.' | head -1)
[ -z "$TARGET" ] && tmux display-message "No pending agents" && exit 0

# Get the pane that created this notification
if [ -f "$DIR/.pane_$TARGET" ]; then
    PANE_ID=$(cat "$DIR/.pane_$TARGET")
    if tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -q "^${PANE_ID}$"; then
        tmux switch-client -t "$PANE_ID"
        tmux select-pane -t "$PANE_ID"
        exit 0
    fi
fi

tmux display-message "Pane for notification no longer exists"
