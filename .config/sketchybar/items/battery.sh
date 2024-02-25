#!/bin/bash

# sketchybar --add bracket data right \
# 	--set data update_freq=120 \
# 	script="$PLUGIN_DIR/battery.sh" \
# 	--subscribe data system_woke power_source_change

sketchybar --add item battery right \
	--set battery update_freq=120 \
	script="$PLUGIN_DIR/battery.sh" \
	background.color=0x00ffffff \
	icon.padding_left=0 \
	icon.padding_right=10 \
	background.border_width=0 \
	--subscribe battery system_woke power_source_change
