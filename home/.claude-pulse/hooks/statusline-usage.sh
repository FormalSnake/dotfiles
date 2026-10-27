#!/bin/sh
# Status line: shows the account's rate-limit use and keeps the last reading in
# state/rate-limits.json, the only place a script can read the weekly percentage from.
dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state"
input=$(cat)
limits=$(printf '%s' "$input" | jq -c '.rate_limits // empty' 2>/dev/null)
if [ -n "$limits" ]; then
  mkdir -p "$dir"
  printf '%s' "$limits" | jq -c --arg at "$(date +%s)" '. + {read_at: ($at | tonumber)}' > "$dir/rate-limits.json.tmp" &&
    mv "$dir/rate-limits.json.tmp" "$dir/rate-limits.json"
  printf '%s' "$limits" | jq -r '"7d \(.seven_day.used_percentage // "?" | if type == "number" then floor else . end)% · 5h \(.five_hour.used_percentage // "?" | if type == "number" then floor else . end)%"'
fi
