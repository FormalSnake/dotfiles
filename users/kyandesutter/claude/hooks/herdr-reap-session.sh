#!/bin/sh
# Record this pane's Claude session id where herdr-reap can find it, so the
# footer it leaves in a reaped pane carries a `claude --resume` that works.
# Herdr is told the session ref by its own integration hook but does not expose
# it over the CLI, and the transcript file cannot be matched back to a pane
# when several agents share a working directory.
set -eu

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

session_id=$(jq -r '.session_id // empty') || exit 0
[ -n "$session_id" ] || exit 0

dir="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-reap/sessions"
mkdir -p "$dir" || exit 0
printf '%s\n' "$session_id" > "$dir/$(printf '%s' "$HERDR_PANE_ID" | tr ':' '-')"
