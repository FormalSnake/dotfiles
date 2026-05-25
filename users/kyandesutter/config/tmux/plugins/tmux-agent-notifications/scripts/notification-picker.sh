#!/usr/bin/env bash
DIR="$HOME/.claude/.notifications"
[ ! -d "$DIR" ] && echo "No notifications" && sleep 1 && exit 0

FILES=$(ls -t "$DIR" 2>/dev/null | grep -v '^\.')
[ -z "$FILES" ] && echo "No notifications" && sleep 1 && exit 0

# Build fzf list: strip tmux formatting, keep notification key for lookup
LIST=""
while IFS= read -r file; do
    CONTENT=$(cat "$DIR/$file" 2>/dev/null)
    [ -z "$CONTENT" ] && continue
    # Strip tmux format codes (#[...])
    CLEAN=$(echo "$CONTENT" | sed 's/#\[[^]]*\]//g' | sed 's/^[[:space:]]*//')
    LIST+="$file	$CLEAN"$'\n'
done <<< "$FILES"

[ -z "$LIST" ] && echo "No notifications" && sleep 1 && exit 0

SELECTED=$(echo "$LIST" | fzf --reverse --header='Jump to notification' --delimiter='\t' --with-nth=2)
[ -z "$SELECTED" ] && exit 0

NOTIF_KEY=$(echo "$SELECTED" | cut -f1)

# Get pane ID and switch to it
if [ -f "$DIR/.pane_$NOTIF_KEY" ]; then
    PANE_ID=$(cat "$DIR/.pane_$NOTIF_KEY")
    if tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -q "^${PANE_ID}$"; then
        rm -f "$DIR/$NOTIF_KEY" "$DIR/.pane_$NOTIF_KEY"
        tmux refresh-client -S 2>/dev/null
        tmux switch-client -t "$PANE_ID"
        tmux select-pane -t "$PANE_ID"
        exit 0
    fi
fi

echo "Pane not found for notification"
sleep 1
