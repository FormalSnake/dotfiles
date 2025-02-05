#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"

battery=(
  # label
  "label.color=$BATTERY"
  background.color="$BATTERY_BACKGROUND"


  # functionality
  update_freq=120
  updates=on
  script="$PLUGIN_DIR/battery.sh"
)
sketchybar --add item battery right \
           --set battery "${battery[@]}" \
           --subscribe battery power_source_change system_woke
