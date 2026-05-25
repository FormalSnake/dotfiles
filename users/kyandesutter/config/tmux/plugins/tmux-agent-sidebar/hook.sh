#!/usr/bin/env bash
# Thin wrapper: delegates to Rust binary.
# Called by Claude Code / Codex hooks (settings.json).
PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd -P)"
if command -v tmux-agent-sidebar &>/dev/null; then
  BIN="tmux-agent-sidebar"
elif [ -x "$PLUGIN_DIR/bin/tmux-agent-sidebar" ]; then
  BIN="$PLUGIN_DIR/bin/tmux-agent-sidebar"
elif [ -x "$PLUGIN_DIR/target/release/tmux-agent-sidebar" ]; then
  BIN="$PLUGIN_DIR/target/release/tmux-agent-sidebar"
else
  exit 0
fi
exec "$BIN" hook "$@"
