#!/usr/bin/env bash
# Weekly Nix update, macbook half. CI owns the lock bump now
# (.github/workflows/update.yml: nix flake update, eval every host, push to
# main on green). This job applies whatever landed:
#   1. Fast-forward the repo to origin/main
#   2. If anything came in, build-test #macbook
#   3. Show a popup asking whether to rebuild now or later
#
# Designed to be called from a launchd user agent. Logs to stdout/stderr;
# the agent's StandardOutPath / StandardErrorPath captures them.
#
# Env vars:
#   FLAKE_DIR  Path to the flake (default: ~/.config/nix)

set -euo pipefail

FLAKE_DIR="${FLAKE_DIR:-$HOME/.config/nix}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROMPT="$SCRIPT_DIR/nix-update-prompt.sh"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

# notify TITLE MESSAGE [critical]
#   No-arg "critical" -> blocking modal alert; otherwise a non-blocking banner.
# Messages must be plain ASCII without double quotes (interpolated into
# AppleScript). Best-effort: never fail the script if there is no GUI session.
notify() {
  local title="$1" message="$2" kind="${3:-}"
  if [[ "$kind" == "critical" ]]; then
    /usr/bin/osascript >/dev/null 2>&1 <<APPLESCRIPT || true
tell me to activate
display alert "$title" message "$message" as critical buttons {"OK"} default button "OK"
APPLESCRIPT
  else
    /usr/bin/osascript >/dev/null 2>&1 <<APPLESCRIPT || true
display notification "$message" with title "$title"
APPLESCRIPT
  fi
}

cd "$FLAKE_DIR"

log "fetching origin/main"
git fetch --quiet origin main

local_rev=$(git rev-parse HEAD)
remote_rev=$(git rev-parse origin/main)
if [[ "$local_rev" == "$remote_rev" ]]; then
  log "already at origin/main (${local_rev:0:8}); nothing to do"
  exit 0
fi

# Never discards local state: --ff-only refuses when local commits aren't on
# origin, and the underlying merge refuses when uncommitted edits overlap
# incoming files. Both mean someone is mid-work in the tree, so report and
# leave it alone.
if ! git merge --ff-only origin/main; then
  log "cannot fast-forward to origin/main; leaving the tree alone"
  notify "Nix weekly update skipped" \
    "The repo could not fast-forward to origin main (local commits or conflicting edits). Pull manually when convenient."
  exit 0
fi

summary=$(git log --oneline --no-decorate "${local_rev}..${remote_rev}" | head -30)
log "pulled:"
printf '%s\n' "$summary" | sed 's/^/  /'

# Build-test before prompting so "Rebuild Now" can't run into a regression
# that CI's eval-only check missed. caffeinate -i prevents idle sleep from
# suspending a long build.
build_log=$(mktemp -t nix-weekly-build.XXXXXX.log)
log "build-testing #macbook (this may take a while)"
if ! /usr/bin/caffeinate -i darwin-rebuild build --flake "${FLAKE_DIR}#macbook" >"$build_log" 2>&1; then
  log "build FAILED"
  log "--- build log tail ---"
  tail -50 "$build_log" | sed 's/^/  /'
  rm -f "$build_log"
  notify "Nix weekly update: build failed" \
    "origin main was pulled but the macbook config does not build from it. Nothing was activated. See ~/Library/Logs/kyan-nix-weekly-update.log." \
    critical
  exit 1
fi
rm -f "$build_log"
log "build OK"

set +e
printf 'Pulled from origin/main:\n%s\n' "$summary" | "$PROMPT"
choice=$?
set -e

case "$choice" in
  0)
    log "user chose Rebuild Now; opening Terminal"
    /usr/bin/osascript <<APPLESCRIPT
tell application "Terminal"
  activate
  do script "cd ${FLAKE_DIR} && just rebuild"
end tell
APPLESCRIPT
    ;;
  10)
    log "user chose Later; leaving the pulled tree in place"
    ;;
  *)
    log "prompt exited unexpectedly with code $choice"
    exit "$choice"
    ;;
esac
