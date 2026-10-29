#!/usr/bin/env bash
LOG_FILE="$HOME/.tmux-notifications/events.log"
[ ! -f "$LOG_FILE" ] && echo "No log file found." && read -rsn1 && exit 0
tail -f "$LOG_FILE" &
TAIL_PID=$!
trap "kill $TAIL_PID 2>/dev/null" EXIT
while IFS= read -rsn1 key; do
    [ "$key" = "q" ] && exit
done
