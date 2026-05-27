#!/usr/bin/env bash
# Weekly Nix update job.
#   1. nix flake update in $FLAKE_DIR
#   2. Compute a summary of which inputs changed
#   3. Show a popup asking whether to rebuild now or later
#   4. If "Rebuild Now": open Terminal and run `just rebuild` so the user sees
#      build progress and TouchID/sudo prompts work via the tty.
#
# Designed to be called from a launchd user agent. Logs to stdout/stderr —
# the agent's StandardOutPath / StandardErrorPath captures them.
#
# Env vars:
#   FLAKE_DIR  Path to the flake (default: ~/.config/nix)

set -euo pipefail

FLAKE_DIR="${FLAKE_DIR:-$HOME/.config/nix}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROMPT="$SCRIPT_DIR/nix-update-prompt.sh"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

cd "$FLAKE_DIR"

if [[ ! -f flake.lock ]]; then
  log "no flake.lock in $FLAKE_DIR; aborting"
  exit 1
fi

before=$(mktemp -t flake-lock-before.XXXXXX)
trap 'rm -f "$before"' EXIT
cp flake.lock "$before"

log "running nix flake update"
nix flake update

if cmp -s "$before" flake.lock; then
  log "no input changes; nothing to do"
  exit 0
fi

# Build a human summary: one line per changed input, "name: old-date → new-date"
summary=$(jq -nr \
  --slurpfile b "$before" \
  --slurpfile a flake.lock \
  '
  def fmtdate(t): if t == null then "?" else (t | todate | .[:10]) end;
  ($b[0].nodes // {}) as $bn
  | ($a[0].nodes // {}) as $an
  | [ $an
      | to_entries[]
      | select(.key != "root")
      | . as $e
      | ($bn[$e.key] // null) as $old
      | if $old == null then
          { kind: "added", name: $e.key,
            new: fmtdate($e.value.locked.lastModified) }
        elif ($old.locked.rev // $old.locked.narHash)
             != ($e.value.locked.rev // $e.value.locked.narHash) then
          { kind: "updated", name: $e.key,
            old: fmtdate($old.locked.lastModified),
            new: fmtdate($e.value.locked.lastModified) }
        else empty
        end
    ]
  + [ $bn
      | to_entries[]
      | select(.key != "root")
      | select($an[.key] == null)
      | { kind: "removed", name: .key }
    ]
  | .[]
  | if .kind == "updated" then "• \(.name): \(.old) → \(.new)"
    elif .kind == "added" then "+ \(.name) (added, \(.new))"
    else "− \(.name) (removed)"
    end
  ')

if [[ -z "$summary" ]]; then
  log "lock changed but no input deltas (?); skipping prompt"
  exit 0
fi

log "changes:"
printf '%s\n' "$summary" | sed 's/^/  /'

set +e
printf 'Updated inputs:\n%s\n' "$summary" | "$PROMPT"
choice=$?
set -e

case "$choice" in
  0)
    log "user chose Rebuild Now — opening Terminal"
    /usr/bin/osascript <<APPLESCRIPT
tell application "Terminal"
  activate
  do script "cd ${FLAKE_DIR} && just rebuild"
end tell
APPLESCRIPT
    ;;
  10)
    log "user chose Later — leaving updated flake.lock in place"
    ;;
  *)
    log "prompt exited unexpectedly with code $choice"
    exit "$choice"
    ;;
esac
