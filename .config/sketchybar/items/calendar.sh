#!/bin/bash

sketchybar --add item calendar c \
           --set calendar icon=􀉉  \
                          update_freq=30 \
                          script="$PLUGIN_DIR/calendar.sh"
