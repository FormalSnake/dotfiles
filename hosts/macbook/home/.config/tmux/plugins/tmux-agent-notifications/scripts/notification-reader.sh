#!/usr/bin/env bash
DIR="$HOME/.tmux-notifications"
[ ! -d "$DIR" ] && exit 0

FILES=$(ls -t "$DIR" 2>/dev/null | grep -v '^\.' | grep -v '^events\.log$')
[ -z "$FILES" ] && exit 0

TOTAL=$(echo "$FILES" | wc -l | tr -d ' ')
WIDTH=$(tmux display-message -p '#{client_width}' 2>/dev/null)
WIDTH="${WIDTH:-200}"

SEP_FG=$(tmux show-option -gqv "@claude-notif-separator-fg" 2>/dev/null)
SEP_FG="${SEP_FG:-#444a73}"

visible_len() {
    echo -n "$1" | sed 's/#\[[^]]*\]//g' | wc -c | tr -d ' '
}

SEP="  #[fg=${SEP_FG}]│#[default]  "
OUTPUT=""
SHOWN=0
while IFS= read -r file; do
    CONTENT=$(cat "$DIR/$file" 2>/dev/null)
    [ -z "$CONTENT" ] && continue
    if [ -n "$OUTPUT" ]; then
        CANDIDATE="$OUTPUT$SEP$CONTENT"
    else
        CANDIDATE="$CONTENT"
    fi
    REMAINING=$((TOTAL - SHOWN - 1))
    if [ "$REMAINING" -gt 0 ]; then
        SUFFIX="  #[fg=${SEP_FG}]│#[fg=yellow,bold]  +${REMAINING} more"
        CHECK="$CANDIDATE$SUFFIX"
    else
        CHECK="$CANDIDATE"
    fi
    LEN=$(visible_len "$CHECK")
    if [ "$LEN" -gt "$WIDTH" ] && [ "$SHOWN" -gt 0 ]; then
        break
    fi
    OUTPUT="$CANDIDATE"
    SHOWN=$((SHOWN + 1))
done <<< "$FILES"

if [ "$SHOWN" -lt "$TOTAL" ]; then
    OUTPUT="$OUTPUT  #[fg=${SEP_FG}]│#[fg=yellow,bold]  +$((TOTAL - SHOWN)) more"
fi

echo "$OUTPUT"
