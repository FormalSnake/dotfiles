#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"

wifi=(
  # label
  "label.color=$WIFI"

  background.color="$WIFI_BACKGROUND"

  # functionality
  update_freq=120
  script="$PLUGIN_DIR/wifi.sh"
)

sketchybar --add item wifi right \
           --set wifi "${wifi[@]}" \
           --subscribe wifi
