#!/bin/sh

if [ "$SENDER" = "front_app_switched" ]; then
  # sketchybar --set "$NAME" label="$INFO" icon.background.image="app.$INFO" icon.background.image.scale=0.8
  sketchybar --set "$NAME" label="$INFO"
fi
