#!/usr/bin/env bash
# Launch an app or focus its existing window
# Usage: launch-or-focus.sh <command> <window-class>

COMMAND="$1"
CLASS="$2"

[[ -z "$COMMAND" ]] && echo "Usage: launch-or-focus.sh <command> <class>" && exit 1

# Default class to command name if not specified
CLASS="${CLASS:-$COMMAND}"

# Check if a window with this class exists
if hyprctl clients -j | jq -e ".[] | select(.class | test(\"$CLASS\"; \"i\"))" >/dev/null 2>&1; then
    # Focus the existing window
    hyprctl dispatch focuswindow "class:$CLASS"
else
    # Launch the application
    hyprctl dispatch exec "$COMMAND"
fi
