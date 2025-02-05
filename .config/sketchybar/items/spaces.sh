#!/usr/bin/env bash

SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "0")

sketchybar --add event aerospace_workspace_change

for m in $(aerospace list-monitors | awk '{print $1}'); do
  for i in $(aerospace list-workspaces --monitor "$m"); do
    echo "i: $i"
    sid=$i

    name_idx=$(( i - 1 ))
    name=${i}

    space=(
      space="$sid"

      display="$m"

      label="$name"
      label.color="$SPACE"

      padding_left=2
      padding_right=2

      script="$PLUGIN_DIR/space.sh"
      click_script="aerospace workspace $i"
    )

    sketchybar --add space "space.$sid" left \
               --set "space.$sid" "${space[@]}" \
               --subscribe "space.$sid" aerospace_workspace_change
  done

  for i in $(aerospace list-workspaces --monitor "$m" --empty); do
    sketchybar --set "space.$i" "display=0"
  done
done

space_creator=(
  icon=􀆊
  icon.font="$FONT:Heavy:16.0"
  padding_left=0
  padding_right=0
  label.drawing=off
  display=active
  script="$PLUGIN_DIR/space_windows.sh"
  icon.color=$WHITE
)

sketchybar --add item space_creator left               \
           --set space_creator "${space_creator[@]}"   \
           --subscribe space_creator aerospace_workspace_change
