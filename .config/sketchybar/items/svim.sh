#!/bin/bash

svim=(
	script="$PLUGIN_DIR/svim.sh"
	icon=$INSERT_MODE
	icon.font.size=20
	updates=on
	drawing=off
	label.font="SF Pro:15.0"
)

sketchybar --add event svim_update \
	--add item svim left \
	--set svim "${svim[@]}" \
	--subscribe svim svim_update
