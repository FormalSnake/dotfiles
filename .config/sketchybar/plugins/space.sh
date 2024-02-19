#!/usr/bin/env bash

# -----------------------------------
# -------- Icons
# -----------------------------------
SPACE_ICONS=('󰯉' '󰯉' '󰯉' '󰯉' '󰯉' '󰯉')

# -----------------------------------
# -------- Colors
# -----------------------------------
UNFOCUS=0xFF838AA7
FOCUS=0xFFFFFFFF

RED=0xFFED8796 ERROR="$RED"
BLUE=0xFF8AADF4 FLOAT_LAYOUT_COLOR="$BLUE"
YELLOW=0xFFEED49F BSP_LAYOUT_COLOR="$YELLOW"
MAGENTA=0xFFC6A0F6 STACK_LAYOUT_COLOR="$MAGENTA"

# -----------------------------------
# -------- Scripts
# -----------------------------------
function update_space_type() {
	border_color="$ERROR" color="$ERROR"
	if [[ "$SELECTED" == 'true' ]]; then
		border_color="$FOCUS"
		space_type="$(yabai -m query --spaces --space | jq -r '.type')"
		if [[ "$space_type" == 'float' ]]; then
			color="$FLOAT_LAYOUT_COLOR"
		elif [[ "$space_type" == 'bsp' ]]; then
			color="$BSP_LAYOUT_COLOR"
		elif [[ "$space_type" == 'stack' ]]; then
			color="$STACK_LAYOUT_COLOR"
		fi
	else
		border_color="$UNFOCUS"
	fi

	sketchybar --set "$NAME" icon.highlight_color="$color" icon.highlight="$SELECTED" \
		label.highlight="$SELECTED" label.highlight_color="$color" \
		background.border_color="$border_color"
}

function update_space_windows() {
	# RETURN: Not selected space, do nothing.
	[[ "$SELECTED" == 'false' ]] && return 0
	# RETURN: Error sender
	[[ "$SENDER" != 'space_windows_change' ]] && echo 'Error SENDER in `update_space_windows`' && return 1

	# NOTE: Info demo (only show the currnet space info)
	# { "space": 1, "apps": { "kitty": 1, "Arc": 1, "Reminders": 1 } }
	# { "space": 2, "apps": { "Arc": 1 } }
	space="$(echo "$INFO" | jq -r '.space')" # NOTE: Different with `$SID`
	apps="$(echo "$INFO" | jq -r '.apps | keys[]')"

	icon_strip=''
	if [ "${apps}" != '' ]; then
		while read -r app; do
			icon_strip+=" $($CONFIG_DIR/scripts/icon_map.sh "$app")"
		done <<<"${apps}"
	else
		icon_strip=' —'
	fi

	sketchybar --animate sin 10 \
		--set space.$space label="$icon_strip"
}

function mouse_clicked() {
	if [[ "$MODIFIER" == 'shift' ]]; then
		space_icon="${SPACE_ICONS[$((SID - 1))]}"
		space_name="$(osascript -e "return (text returned of (display dialog \"Give a name to space $NAME:\" default answer \"\" with icon note buttons {\"Cancel\", \"Continue\"} default button \"Continue\"))")"
		if [[ "$?" == 0 ]]; then
			icon="$([[ "$space_name" == '' ]] && echo "$space_icon" || echo "$space_icon ($space_name)")"
			sketchybar --set "$NAME" icon="$icon"
		fi
	elif [[ "$BUTTON" == 'left' ]]; then
		yabai -m space --focus "$SID"
	elif [[ "$BUTTON" == 'right' ]]; then
		yabai -m space --destroy "$SID"
	fi
}

# -----------------------------------
# -------- Trigger
# -----------------------------------
case "$SENDER" in
'mouse.clicked')
	mouse_clicked
	;;
'forced' | 'skhd_space_type_changed' | 'space_change' | 'yabai_loaded')
	update_space_type
	;;
'space_windows_change')
	update_space_windows
	;;
'yabai_window_created' | 'yabai_application_visible')
	[[ "$SELECTED" == 'true' ]] && sketchybar --trigger space_windows_change
	;;
*)
	echo "Invalid sender: $SENDER" in $0
	;;
esac
