#!/usr/bin/env bash
SESSION="$1"
PANE_PATH="$2"
PANE_ID="$3"
NOTIF_DIR="$HOME/.tmux-notifications"

[ -z "$PANE_ID" ] && exit 0

LIVE_PANES=$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null)

for pane_file in "$NOTIF_DIR"/.pane_*; do
    [ -f "$pane_file" ] || continue
    STORED_PANE=$(cat "$pane_file")
    NOTIF_KEY=$(basename "$pane_file" | sed 's/^\.pane_//')

    if [ "$STORED_PANE" = "$PANE_ID" ] || ! echo "$LIVE_PANES" | grep -q "^${STORED_PANE}$" || [ -z "$(echo "$STORED_PANE" | tr -d '[:space:]')" ]; then
        rm -f "$pane_file" "$NOTIF_DIR/$NOTIF_KEY"
        continue
    fi

    # Clear stale notifications older than 30 minutes
    if [ "$(uname)" = "Darwin" ]; then
        FILE_AGE=$(( $(date +%s) - $(stat -f %m "$pane_file") ))
    else
        FILE_AGE=$(( $(date +%s) - $(stat -c %Y "$pane_file") ))
    fi
    if [ "$FILE_AGE" -gt 1800 ]; then
        rm -f "$pane_file" "$NOTIF_DIR/$NOTIF_KEY"
    fi
done

tmux refresh-client -S 2>/dev/null
