{
  config,
  pkgs,
  lib,
  ...
}: let
  # Catppuccin Mocha color scheme
  colors = {
    # Base colors
    base = "0xff1e1e2e";
    mantle = "0xff181825";
    crust = "0xff11111b";
    
    # Text colors
    text = "0xffcdd6f4";
    subtext1 = "0xffbac2de";
    subtext0 = "0xffa6adc8";
    
    # Surface colors
    surface0 = "0xff313244";
    surface1 = "0xff45475a";
    surface2 = "0xff585b70";
    
    # Accent colors
    blue = "0xff89b4fa";
    lavender = "0xffb4befe";
    sapphire = "0xff74c7ec";
    sky = "0xff89dceb";
    teal = "0xff94e2d5";
    green = "0xffa6e3a1";
    yellow = "0xfff9e2af";
    peach = "0xfffab387";
    maroon = "0xffeba0ac";
    red = "0xfff38ba8";
    mauve = "0xffcba6f7";
    pink = "0xfff5c2e7";
    flamingo = "0xfff2cdcd";
    rosewater = "0xfff5e0dc";
  };

  # Aerospace workspace integration script
  aerospaceScript = pkgs.writeShellScript "aerospace.sh" ''
    #!/bin/bash
    
    # Get current workspace from aerospace
    CURRENT_WORKSPACE=$(aerospace list-workspaces --focused)
    MONITOR=$(aerospace list-monitors --focused | head -n1)
    
    # Update all workspace indicators
    for i in {1..9}; do
      if [[ "$i" == "$CURRENT_WORKSPACE" ]]; then
        sketchybar --set space.$i background.drawing=on \
                              background.color=${colors.blue} \
                              label.color=${colors.base} \
                              icon.color=${colors.base}
      else
        # Check if workspace has windows
        if aerospace list-windows --workspace $i &>/dev/null; then
          sketchybar --set space.$i background.drawing=on \
                                background.color=${colors.surface1} \
                                label.color=${colors.text} \
                                icon.color=${colors.text}
        else
          sketchybar --set space.$i background.drawing=off \
                                label.color=${colors.subtext0} \
                                icon.color=${colors.subtext0}
        fi
      fi
    done
  '';
  
  # Individual space script for clicks and updates
  spaceScript = pkgs.writeShellScript "space.sh" ''
    #!/bin/bash
    
    # This script runs when aerospace workspace changes
    CURRENT_WORKSPACE=$(aerospace list-workspaces --focused)
    
    if [[ "$NAME" == "space.$CURRENT_WORKSPACE" ]]; then
      sketchybar --set $NAME background.drawing=on \
                        background.color=${colors.blue} \
                        label.color=${colors.base} \
                        icon.color=${colors.base}
    else
      # Check if this workspace has windows
      WORKSPACE_NUM=''${NAME#space.}
      if aerospace list-windows --workspace $WORKSPACE_NUM &>/dev/null; then
        sketchybar --set $NAME background.drawing=on \
                              background.color=${colors.surface1} \
                              label.color=${colors.text} \
                              icon.color=${colors.text}
      else
        sketchybar --set $NAME background.drawing=off \
                              label.color=${colors.subtext0} \
                              icon.color=${colors.subtext0}
      fi
    fi
  '';
  
  # Front app script with nerd font icons
  frontAppScript = pkgs.writeShellScript "front_app.sh" ''
    #!/bin/bash
    
    INFO="$INFO"
    if [ -z "$INFO" ]; then
      INFO=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true')
    fi
    
    # Set icon based on application
    case "$INFO" in
      "Brave Browser"|"Safari"|"Chrome"|"Firefox") ICON="󰖟" ;;
      "Ghostty"|"Terminal"|"iTerm2"|"Alacritty") ICON="" ;;
      "Zed"|"Visual Studio Code"|"Neovim") ICON="󰨞" ;;
      "Slack") ICON="󰒱" ;;
      "WhatsApp"|"Messages") ICON="󰭹" ;;
      "Notion") ICON="󰃇" ;;
      "Figma") ICON="󰣇" ;;
      "Claude"|"ChatGPT") ICON="󰚩" ;;
      "Spotify") ICON="󰓇" ;;
      "Steam") ICON="󰓓" ;;
      "Finder") ICON="󰀶" ;;
      "System Preferences"|"System Settings") ICON="" ;;
      *) ICON="󰘔" ;;
    esac
    
    sketchybar --set front_app icon="$ICON" label="$INFO"
  '';
  
  # Battery script with enhanced nerd font icons
  batteryScript = pkgs.writeShellScript "battery.sh" ''
    #!/bin/bash
    
    PERCENTAGE=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
    CHARGING=$(pmset -g batt | grep 'AC Power')
    
    if [ $PERCENTAGE = "" ]; then
      exit 0
    fi
    
    # Enhanced battery icons
    if [[ $CHARGING != "" ]]; then
      case ''${PERCENTAGE} in
        9[0-9]|100) ICON="󰂅" ;;
        [8-9][0-9]) ICON="󰂋" ;;
        [6-7][0-9]) ICON="󰂊" ;;
        [4-5][0-9]) ICON="󰢞" ;;
        [2-3][0-9]) ICON="󰢝" ;;
        *) ICON="󰢜" ;;
      esac
    else
      case ''${PERCENTAGE} in
        9[0-9]|100) ICON="󰁹" ;;
        [8-9][0-9]) ICON="󰂂" ;;
        [6-7][0-9]) ICON="󰂀" ;;
        [4-5][0-9]) ICON="󰁾" ;;
        [2-3][0-9]) ICON="󰁼" ;;
        [1-2][0-9]) ICON="󰁺" ;;
        *) ICON="󰂎" ;;
      esac
    fi
    
    # Color coding based on battery level
    if [ $PERCENTAGE -le 20 ]; then
      COLOR=${colors.red}
    elif [ $PERCENTAGE -le 50 ]; then
      COLOR=${colors.yellow}
    else
      COLOR=${colors.green}
    fi
    
    sketchybar --set battery icon="$ICON" \
                          icon.color="$COLOR" \
                          label="''${PERCENTAGE}%"
  '';

  # Clock script with enhanced formatting
  clockScript = pkgs.writeShellScript "clock.sh" ''
    #!/bin/bash
    
    sketchybar --set clock label="$(date '+%a %d %b %H:%M')"
  '';
  
  # Spotify script
  spotifyScript = pkgs.writeShellScript "spotify.sh" ''
    #!/bin/bash
    
    # Check if Spotify is running
    if ! pgrep -x "Spotify" > /dev/null; then
      sketchybar --set spotify drawing=off
      exit 0
    fi
    
    # Get current track info
    TRACK=$(osascript -e 'tell application "Spotify" to get name of current track' 2>/dev/null)
    ARTIST=$(osascript -e 'tell application "Spotify" to get artist of current track' 2>/dev/null)
    STATE=$(osascript -e 'tell application "Spotify" to get player state' 2>/dev/null)
    
    if [[ $TRACK == "" ]] || [[ $ARTIST == "" ]]; then
      sketchybar --set spotify drawing=off
      exit 0
    fi
    
    # Set icon based on play state
    if [[ $STATE == "playing" ]]; then
      ICON="󰏤"
    else
      ICON="󰐊"
    fi
    
    # Truncate long track names
    if [[ ''${#TRACK} -gt 20 ]]; then
      TRACK="''${TRACK:0:17}..."
    fi
    
    if [[ ''${#ARTIST} -gt 15 ]]; then
      ARTIST="''${ARTIST:0:12}..."
    fi
    
    sketchybar --set spotify drawing=on \
                         icon="$ICON" \
                         label="$TRACK - $ARTIST"
  '';

  # Main configuration string
  sketchybarConfig = ''
    #!/bin/bash
    
    # This is a generated file, do not edit!
    
    ############## BAR ##############
    sketchybar --bar height=32 \
                    blur_radius=30 \
                    position=top \
                    sticky=off \
                    padding_left=10 \
                    padding_right=10 \
                    color=${colors.base} \
                    border_width=2 \
                    border_color=${colors.surface0} \
                    corner_radius=0
    
    ############## GLOBAL DEFAULTS ##############
    sketchybar --default icon.font="GeistMono Nerd Font:Bold:16.0" \
                        icon.color=${colors.text} \
                        label.font="GeistMono Nerd Font:Bold:14.0" \
                        label.color=${colors.text} \
                        background.color=${colors.surface0} \
                        background.corner_radius=6 \
                        background.height=24 \
                        padding_left=5 \
                        padding_right=5 \
                        label.padding_left=4 \
                        label.padding_right=10 \
                        icon.padding_left=10 \
                        icon.padding_right=4
    
    ############## SPACE INDICATORS ##############
    # Create workspace indicators with proper aerospace integration
    for i in {1..9}; do
      sketchybar --add space space.$i left \
                 --set space.$i associated_space=$i \
                                icon="$i" \
                                icon.font="GeistMono Nerd Font:Bold:16.0" \
                                label.drawing=off \
                                script="${spaceScript}" \
                                click_script="aerospace workspace $i"
    done
    
    # Subscribe to aerospace events
    sketchybar --add event aerospace_workspace_change
    for i in {1..9}; do
      sketchybar --subscribe space.$i aerospace_workspace_change
    done
    
    ############## LEFT SIDE ITEMS ##############
    sketchybar --add item space_separator left \
               --set space_separator icon="" \
                                     label.drawing=off \
                                     background.drawing=off \
                                     padding_left=10
    
    sketchybar --add item front_app left \
               --set front_app       script="${frontAppScript}" \
                                     icon.font="GeistMono Nerd Font:Bold:16.0" \
                                     background.color=${colors.surface1} \
               --subscribe front_app front_app_switched
    
    ############## RIGHT SIDE ITEMS ##############
    sketchybar --add item clock right \
               --set clock           update_freq=10 \
                                     icon="󰥔" \
                                     script="${clockScript}" \
                                     background.color=${colors.surface1}
    
    sketchybar --add item battery right \
               --set battery         update_freq=30 \
                                     script="${batteryScript}" \
                                     background.color=${colors.surface1} \
               --subscribe battery   power_source_change system_woke
    
    sketchybar --add item spotify right \
               --set spotify         update_freq=2 \
                                     script="${spotifyScript}" \
                                     background.color=${colors.surface1} \
                                     click_script="osascript -e 'tell application \"Spotify\" to playpause'" \
                                     drawing=off
    
    ############## FINALIZING THE SETUP ##############
    # Start aerospace integration
    ${aerospaceScript} &
    
    # Set up aerospace workspace change listener
    aerospace listen-event workspace-changed --command "${aerospaceScript}" &
    
    sketchybar --update
    
    echo "sketchybar configuation loaded.."  # log stdout
  '';
in {
  programs.sketchybar = {
    enable = true;
    config = sketchybarConfig;
    
    # Enable the service to start automatically
    service.enable = true;
    
    # Extra packages needed for scripts
    extraPackages = with pkgs; [
      jq
      # Note: aerospace should already be available from the aerospace module
    ];
  };
}