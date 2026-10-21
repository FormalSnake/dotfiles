#!/bin/bash

# Install Codex CLI notification hook
# Adds notify path to ~/.codex/config.toml

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFY_PATH="$SCRIPT_DIR/notify.sh"
CONFIG="$HOME/.codex/config.toml"

if [ ! -f "$CONFIG" ]; then
    mkdir -p "$HOME/.codex"
    echo "notify = [\"$NOTIFY_PATH\"]" > "$CONFIG"
    echo "Codex config created at $CONFIG"
    exit 0
fi

if grep -q "^notify" "$CONFIG"; then
    if grep -q "$NOTIFY_PATH" "$CONFIG"; then
        echo "Already configured."
    else
        echo "notify already set in $CONFIG — add manually:"
        echo "  notify = [\"$NOTIFY_PATH\"]"
    fi
else
    sed -i.bak "1a\\
notify = [\"$NOTIFY_PATH\"]
" "$CONFIG"
    rm -f "$CONFIG.bak"
    echo "Added notify hook to $CONFIG"
fi
