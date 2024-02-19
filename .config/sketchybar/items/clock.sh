#!/bin/bash

sketchybar --add item calendar r \
	--set calendar icon=󰥔 \
	update_freq=30 \
	script="$PLUGIN_DIR/clock.sh"
