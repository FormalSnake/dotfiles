#!/usr/bin/env bash
# Launch a TUI application in a floating ghostty window
# Usage: launch-tui.sh <title> <command> [args...]

TITLE="$1"
shift
COMMAND="$*"

[[ -z "$TITLE" || -z "$COMMAND" ]] && echo "Usage: launch-tui.sh <title> <command> [args...]" && exit 1

ghostty --title=tui-float -e bash -c "$COMMAND"
