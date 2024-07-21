#!/bin/bash

# Packages
brew install lua
brew install switchaudio-osx
brew install nowplaying-cli

brew tap FelixKratz/formulae
brew install sketchybar

# Fonts
brew install --cask sf-symbols

# AppleScript to monitor dark mode
CONFIG_DIR="$HOME/.config/sketchybar"
APPLE_SCRIPT_PATH="$CONFIG_DIR/items/scripts/MonitorDarkMode.scpt"

mkdir -p "$CONFIG_DIR"

cat << 'EOF' > "$APPLE_SCRIPT_PATH"
use framework "AppKit"
use scripting additions

-- Function to check current interface style
on getInterfaceStyle()
    tell application "System Events"
        tell appearance preferences
            return dark mode
        end tell
    end tell
end getInterfaceStyle

-- Main loop to monitor changes
repeat
    set currentMode to getInterfaceStyle()
    delay 10 -- Check every 10 seconds

    if (currentMode is not getInterfaceStyle()) then
        do shell script "/usr/local/bin/brew services restart sketchybar" with administrator privileges
    end if
end repeat
EOF

echo "AppleScript created at $APPLE_SCRIPT_PATH"

# Create the launchd plist file
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.monitorDarkMode.plist"

cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>Label</key>
        <string>com.user.monitorDarkMode</string>
        <key>ProgramArguments</key>
        <array>
            <string>/usr/bin/osascript</string>
            <string>$APPLE_SCRIPT_PATH</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <true/>
    </dict>
</plist>
EOF

echo "launchd plist created at $PLIST_PATH"

# Load the plist with launchctl
launchctl unload "$PLIST_PATH" 2> /dev/null
launchctl load "$PLIST_PATH"

echo "launchd plist loaded. Dark mode monitoring script is now active."

# Optional: Restart SketchyBar to apply any changes
brew services restart sketchybar

echo "Installation and setup complete."