#!/usr/bin/env bash
 
# echo AEROSPACE_PREV_WORKSPACE: $AEROSPACE_PREV_WORKSPACE, \
#  AEROSPACE_FOCUSED_WORKSPACE: $AEROSPACE_FOCUSED_WORKSPACE \
#  SELECTED: $SELECTED \
#  BG2: $BG2 \
#  INFO: $INFO \
#  SENDER: $SENDER \
#  NAME: $NAME \
#   >> ~/aaaa

source "$CONFIG_DIR/colors.sh"

AEROSPACE_FOCUSED_MONITOR=$(aerospace list-monitors --focused | awk '{print $1}')
AEROSAPCE_WORKSPACE_FOCUSED_MONITOR=$(aerospace list-workspaces --monitor focused --empty no)
AEROSPACE_EMPTY_WORKESPACE=$(aerospace list-workspaces --monitor focused --empty)

if [ "$SENDER" = "aerospace_workspace_change" ]; then
  echo "space windows plugin activated"
  # current workspace space border color
  sketchybar --set "space.$AEROSPACE_FOCUSED_WORKSPACE" "label.color=$SPACE_SELECTED" "background.color=$SPACE_SELECTED_BACKGROUND"

  # prev workspace space border color
  sketchybar --set "space.$AEROSPACE_PREV_WORKSPACE" "label.color=$SPACE" "background.color=$SPACE_BACKGROUND"

  for i in $AEROSAPCE_WORKSPACE_FOCUSED_MONITOR; do
    sketchybar --set "space.$i" "display=$AEROSPACE_FOCUSED_MONITOR"
  done

  for i in $AEROSPACE_EMPTY_WORKESPACE; do
    sketchybar --set "space.$i" "display=0"
  done

  sketchybar --set space.$AEROSPACE_FOCUSED_WORKSPACE display=$AEROSPACE_FOCUSED_MONITOR
fi
