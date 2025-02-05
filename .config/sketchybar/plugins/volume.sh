#!/bin/bash

VOLUME=$(osascript -e "output volume of (get volume settings)")
MUTED=$(osascript -e "output muted of (get volume settings)")

OUTPUT="$VOLUME%"
if [[ "$MUTED" != "false" ]]; then
  OUTPUT="muted"
fi

sketchybar --set "$NAME" label="V ⋮ $OUTPUT"
