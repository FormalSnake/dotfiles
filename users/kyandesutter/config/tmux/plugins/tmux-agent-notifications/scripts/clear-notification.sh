#!/usr/bin/env bash
SESSION="$1"
PANE_PATH="$2"
PANE_ID="$3"
NOTIF_DIR="$HOME/.claude/.notifications"

[ -z "$PANE_ID" ] && exit 0

# Find notification for this specific pane
for pane_file in "$NOTIF_DIR"/.pane_*; do
    [ -f "$pane_file" ] || continue
    STORED_PANE=$(cat "$pane_file")
    [ "$STORED_PANE" != "$PANE_ID" ] && continue

    NOTIF_KEY=$(basename "$pane_file" | sed 's/^\.pane_//')
    rm -f "$pane_file" "$NOTIF_DIR/$NOTIF_KEY"
    break
done

tmux refresh-client -S 2>/dev/null
