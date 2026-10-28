#!/usr/bin/env bash
# Stop dev VMs nobody is using. A dev script (FormalShell's dev/vm.sh and
# dev/linux-builder.sh) boots qemu in the background and nothing ever shuts it
# down: in Oct 2026 three of them sat on 24 GB of the macbook's 32 GB for a
# week after the checkout they were booted from was moved.
#
# Every qemu-system process owned by this user counts. A VM is busy while any
# TCP connection is established on one of its hostfwd ports (ssh, nix ssh-ng
# builds); it is stopped once it has gone IDLE_HOURS without one, measured from
# its last seen connection or, never having had one, from its start.
# nix-rosetta-builder and Determinate's builder run on Virtualization.framework,
# not qemu, so they are never matched.
#
# Run every 15 minutes by the kyan-dev-vm-reaper launchd agent. --dry-run
# reports without stopping anything.
#
# Env: IDLE_HOURS (default 2).

set -euo pipefail

IDLE_HOURS="${IDLE_HOURS:-2}"
dry_run=0
[[ "${1:-}" == "--dry-run" ]] && dry_run=1

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dev-vm-reaper"
mkdir -p "$state_dir"
now=$(date +%s)
limit=$((IDLE_HOURS * 3600))

# ps etime: [[dd-]hh:]mm:ss
etime_seconds() {
  local t=$1 d=0 h=0 m s
  [[ $t == *-* ]] && { d=${t%%-*}; t=${t#*-}; }
  IFS=: read -r -a parts <<<"$t"
  if ((${#parts[@]} == 3)); then
    h=${parts[0]} m=${parts[1]} s=${parts[2]}
  else
    m=${parts[0]} s=${parts[1]}
  fi
  echo $((10#$d * 86400 + 10#$h * 3600 + 10#$m * 60 + 10#$s))
}

live=()
while read -r pid; do
  [[ -n $pid ]] || continue
  live+=("$pid")
  stamp="$state_dir/$pid"
  name=$(ps -o command= -p "$pid" | sed -n 's/.* -name \([^ ]*\).*/\1/p')
  name=${name:-qemu}

  if lsof -nP -a -p "$pid" -iTCP -sTCP:ESTABLISHED >/dev/null 2>&1; then
    touch "$stamp"
    continue
  fi

  age=$(etime_seconds "$(ps -o etime= -p "$pid" | tr -d ' ')")
  idle=$age
  if [[ -f $stamp ]]; then
    since=$((now - $(stat -f %m "$stamp")))
    ((since < idle)) && idle=$since
  fi
  ((idle < limit)) && continue

  echo "$(date '+%F %T') $name (pid $pid) idle $((idle / 3600))h, stopping"
  ((dry_run)) && continue
  # qemu flushes its disk images on SIGTERM; the guest just loses power.
  kill -TERM "$pid" 2>/dev/null || continue
  for _ in {1..30}; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
  kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null
  rm -f "$stamp"
done < <(pgrep -U "$(id -u)" -f '/qemu-system-' || true)

# Stamps of VMs that exited on their own.
for stamp in "$state_dir"/*; do
  [[ -e $stamp ]] || continue
  pid=${stamp##*/}
  [[ " ${live[*]-} " == *" $pid "* ]] || rm -f "$stamp"
done
