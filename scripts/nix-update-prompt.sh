#!/usr/bin/env bash
# Show a macOS popup summarising what was updated in flake.lock and ask
# whether to rebuild now or later.
#
# Usage:
#   nix-update-prompt.sh "<summary text>"
#   <pipe summary> | nix-update-prompt.sh
#
# Exit codes:
#   0  -> user chose "Rebuild Now"
#   10 -> user chose "Later"

set -euo pipefail

SUMMARY="${1:-$(cat)}"

MAX_LINES=30
total=$(printf '%s\n' "$SUMMARY" | wc -l | tr -d ' ')
if (( total > MAX_LINES )); then
  body=$(printf '%s\n' "$SUMMARY" | head -n "$MAX_LINES")
  body="${body}"$'\n'"… and $((total - MAX_LINES)) more line(s)"
else
  body="$SUMMARY"
fi

# Pass the body through a temp file so AppleScript can decode it as UTF-8.
# `system attribute` returns text in the local (non-UTF-8) encoding, which
# mangles characters like • and …
msgfile=$(mktemp -t nix-update-msg.XXXXXX)
trap 'rm -f "$msgfile"' EXIT
printf '%s' "$body" > "$msgfile"

choice=$(NIX_UPDATE_MSG_FILE="$msgfile" osascript <<'APPLESCRIPT'
set msgFile to system attribute "NIX_UPDATE_MSG_FILE"
set msg to read (POSIX file msgFile) as «class utf8»
tell me to activate
set theAlert to display alert "Nix flake updated" message msg ¬
  buttons {"Later", "Rebuild Now"} ¬
  default button "Rebuild Now"
button returned of theAlert
APPLESCRIPT
)

case "$choice" in
  "Rebuild Now") exit 0 ;;
  *)             exit 10 ;;
esac
