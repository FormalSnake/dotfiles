#!/usr/bin/env bash

# -----------------------------------
# -------- Icons
# -----------------------------------
SPACE_ICONS=('󰯉' '󰯉' '󰯉' '󰯉' '󰯉' '󰯉')
SPACE_CREATE=

# -----------------------------------
# -------- Fields
# -----------------------------------
ICON_FONT="JetBrainsMono Nerd Font:Regular:12.0"
CREATOR_ICON_FONT="JetBrainsMono Nerd Font:Bold:16.0"
LABEL_FONT="JetBrainsMono Nerd Font:Regular:17.0"

# -----------------------------------
# -------- Scripts
# -----------------------------------
CREATE_SPACE='yabai -m space --create'

# -----------------------------------
# -------- Preferences
# -----------------------------------
space=(
	update_freq=0
	script="$PLUGIN_DIR/space.sh"
	padding_left="$ITEM_MARGIN"

	# icon="${SPACE_ICONS[i]}"
	icon.font="$ICON_FONT"
	icon.color="$GRAY"
	icon.highlight_color="$YELLOW"
	icon.padding_left=5
	icon.y_offset=4

	label.font="$LABEL_FONT"
	label.color="$GRAY"
	label.highlight_color="$YELLOW"
	label.padding_left=0
	label.padding_right=13
	label.y_offset=-2

	background.color="$BACKGROUND_COLOR"
	background.border_color="$WHITE"
	background.corner_radius=5
)

space_creator=(
	update_freq=0
	display=active
	click_script="$CREATE_SPACE"
	padding_left="$ITEM_MARGIN"

	icon="$SPACE_CREATE"
	icon.font="$CREATOR_ICON_FONT"
	icon.color="$GREEN"

	label.drawing=off
)

# -----------------------------------
# -------- Setup
# -----------------------------------
for i in "${!SPACE_ICONS[@]}"; do
	sid=$(($i + 1))
	sketchybar --add space space.$sid left \
		--set space.$sid "${space[@]}" \
		--set space.$sid space=$sid \
		--set space.$sid icon="${SPACE_ICONS[i]}" \
		--subscribe space.$sid mouse.clicked \
		space_change skhd_space_type_changed yabai_loaded \
		space_windows_change yabai_window_created yabai_application_visible
done

sketchybar --add item space_creator left \
	--set space_creator "${space_creator[@]}"
