#!/bin/bash

SPACE_SIDS=(1 2 3 4 5 6 7 8 9 10)

for sid in "${SPACE_SIDS[@]}"
do
  sketchybar --add space space.$sid left                                 \
             --set space.$sid space=$sid                                 \
                              background.corner_radius=100  \
                              background.height=16 \
                              script="$PLUGIN_DIR/space.sh"
done

sketchybar --add item space_separator left                             \
           --set space_separator icon="[\\\]"                                \
                                 icon.color=$ACCENT_COLOR \
                                 label.drawing=off                     \
                                 background.drawing=off                \
           --subscribe space_separator space_windows_change
