scripts/get-icons
#!/bin/zsh

get_icons() {
    local session_name="$1"
    local result=""

  local panes=($(tmux list-panes -t "$session_name" -F '#{pane_current_command}'))

  for i in "${panes[@]}"; do
      case "$i" in
          nvim) result+=" " ;;
          zsh | *)    result+=" " ;;
      esac
  done

    echo "$result"
}

if (( $# != 1 )); then
    echo "Usage: $0 <session-name>"
    exit 1
fi

get_icons "$1"
