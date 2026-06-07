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

if [[ ! -f flake.lock ]]; then
  log "no flake.lock in $FLAKE_DIR; aborting"
  exit 1
fi

before=$(mktemp -t flake-lock-before.XXXXXX)

# lock_dirty=1 marks the danger window: flake.lock has been updated but not yet
# validated by a successful build-test. If we are killed (launchd reloading the
# agent during a manual rebuild, logout, Ctrl-C, …) inside that window we revert
# the untested lock and tell the user, instead of dying silently and leaving an
# unvalidated flake.lock behind (the 2026-05-30 failure mode).
lock_dirty=0

finish() {
  # Runs on every exit. If we still hold an untested lock here, something failed
  # outside the explicit build-test path (e.g. jq erroring) — revert rather than
  # leave an unvalidated flake.lock behind.
  if [[ "$lock_dirty" == "1" ]]; then
    log "exiting with untested flake.lock — reverting"
    cp "$before" flake.lock 2>/dev/null || true
    notify "Nix weekly update aborted" \
      "An untested flake.lock was reverted. See ~/Library/Logs/kyan-nix-weekly-update.log."
  fi
  rm -f "$before"
}

on_interrupt() {
  local sig="$1"
  if [[ "$lock_dirty" == "1" ]]; then
    log "received SIG${sig} mid-update — reverting flake.lock"
    cp "$before" flake.lock 2>/dev/null || true
    notify "Nix weekly update interrupted" \
      "Build-test was interrupted (SIG${sig}); flake.lock reverted. See ~/Library/Logs/kyan-nix-weekly-update.log."
    lock_dirty=0  # handled here; stop the EXIT trap from reverting/notifying again
  else
    log "received SIG${sig} — no untested lock to revert"
  fi
  # 128 + signal number convention (TERM=15, INT=2, HUP=1).
  case "$sig" in TERM) exit 143 ;; INT) exit 130 ;; HUP) exit 129 ;; *) exit 1 ;; esac
}

trap finish EXIT
trap 'on_interrupt TERM' TERM
trap 'on_interrupt INT' INT
trap 'on_interrupt HUP' HUP

cp flake.lock "$before"

log "running nix flake update"
lock_dirty=1
nix flake update

if cmp -s "$before" flake.lock; then
  log "no input changes; nothing to do"
  lock_dirty=0
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

# Validate the new lock by build-testing the macbook config. If it fails we
# revert flake.lock so the next `just rebuild` doesn't trip over upstream
# regressions (e.g. an unbuildable darwin package landing in nixpkgs).
build_log=$(mktemp -t nix-weekly-build.XXXXXX.log)
log "build-testing #macbook (this may take a while)…"
# caffeinate -i prevents idle sleep from suspending/killing a long build-test.
if ! /usr/bin/caffeinate -i darwin-rebuild build --flake "${FLAKE_DIR}#macbook" >"$build_log" 2>&1; then
  log "build FAILED — reverting flake.lock"
  cp "$before" flake.lock
  lock_dirty=0
  log "--- build log tail ---"
  tail -50 "$build_log" | sed 's/^/  /'
  rm -f "$build_log"
  notify "Nix weekly update reverted" \
    "Updating flake inputs produced a config that does not build. flake.lock has been reverted. See ~/Library/Logs/kyan-nix-weekly-update.log." \
    critical
  exit 1
fi
rm -f "$build_log"
# Lock is now validated by a successful build — safe to keep even if the prompt
# below is interrupted, so we leave the danger window.
lock_dirty=0
log "build OK"

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
