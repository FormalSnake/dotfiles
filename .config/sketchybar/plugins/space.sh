#!/bin/sh

# The $SELECTED variable is available for space components and indicates if
# the space invoking this script (with name: $NAME) is currently selected:
# https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item

source "$CONFIG_DIR/colors.sh" # Loads all defined colors

if [ $SELECTED = true ]; then
  sketchybar --set $NAME background.drawing=on \
                     blur_radius=30   \
                         background.color=$ACCENT_COLOR \
                         label.color=$BAR_COLOR \
                         width=32  \
                         icon.color=$BAR_COLOR
else
  sketchybar --set $NAME background.drawing=on \
                     blur_radius=30   \
                         background.color=$ITEM_BG_COLOR \
                         label.color=$ACCENT_COLOR \
                         width=16 \
                         icon.color=$ACCENT_COLOR
fi
