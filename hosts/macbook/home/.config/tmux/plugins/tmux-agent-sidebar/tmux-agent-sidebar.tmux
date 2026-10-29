#!/usr/bin/env bash

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -x "$PLUGIN_DIR/bin/tmux-agent-sidebar" ]]; then
    SIDEBAR_BINARY="$PLUGIN_DIR/bin/tmux-agent-sidebar"
elif [[ -x "$PLUGIN_DIR/target/release/tmux-agent-sidebar" ]]; then
    SIDEBAR_BINARY="$PLUGIN_DIR/target/release/tmux-agent-sidebar"
elif command -v "tmux-agent-sidebar" &>/dev/null; then
    SIDEBAR_BINARY="tmux-agent-sidebar"
fi

if [[ -z "$SIDEBAR_BINARY" ]]; then
    tmux run-shell -b "bash '$PLUGIN_DIR/install-wizard.sh'"
    exit 0
fi

INSTALLED_VERSION="$("$SIDEBAR_BINARY" version 2>/dev/null)"
EXPECTED_VERSION="$(sed -n 's/^version *= *"\(.*\)"/\1/p' "$PLUGIN_DIR/Cargo.toml")"

if [[ -n "$EXPECTED_VERSION" && "$INSTALLED_VERSION" != "$EXPECTED_VERSION" ]]; then
    tmux run-shell -b "SIDEBAR_UPDATE=1 bash '$PLUGIN_DIR/install-wizard.sh'"
    exit 0
fi

tmux set -g @agent_sidebar_bin "$SIDEBAR_BINARY"

tmux source-file "$PLUGIN_DIR/agent-sidebar.conf"
