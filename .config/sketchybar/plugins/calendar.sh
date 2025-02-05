#!/bin/bash

#sketchybar --set $NAME icon="$(date '+%a %d. %b')" label="$(date '+%H:%M')"
sketchybar --set "$NAME" label="$(date '+%A, %d %b %Y ⋮ %H:%M')"
