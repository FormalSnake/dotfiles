#!/usr/bin/env bash
DIR="$HOME/.tmux-notifications"
[ ! -d "$DIR" ] && exit 0

TARGET=$(ls -t "$DIR" 2>/dev/null | grep -v '^\.' | grep -v '^events\.log$' | head -1)
[ -z "$TARGET" ] && tmux display-message "No pending agents" && exit 0

if [ -f "$DIR/.pane_$TARGET" ]; then
    PANE_ID=$(cat "$DIR/.pane_$TARGET")
    if tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -q "^${PANE_ID}$"; then
        rm -f "$DIR/$TARGET" "$DIR/.pane_$TARGET"
        tmux refresh-client -S 2>/dev/null
        tmux switch-client -t "$PANE_ID"
        tmux select-pane -t "$PANE_ID"
        exit 0
    fi
fi

rm -f "$DIR/$TARGET" "$DIR/.pane_$TARGET"
tmux refresh-client -S 2>/dev/null
tmux display-message "Pane gone, notification cleared"
