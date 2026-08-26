#!/usr/bin/env bash
# Reclaim disk on the macbook by deleting only things one command regenerates:
# stale build artifacts, package-manager caches, Xcode derived data, and old nix
# generations. Nothing here touches source, media, or app data.
#
# Dry run by default. Pass --apply to delete.
#
#   mac-storage-gc.sh                  what would go, plus the manual-review list
#   mac-storage-gc.sh --apply          delete it
#   mac-storage-gc.sh --apply --age 7  more aggressive staleness cutoff
#   mac-storage-gc.sh --apply --deep   also Go modcache and old iOS DeviceSupport
#
# Two safety rules gate every directory delete:
#   1. Inside a git work tree, the directory must be git-ignored. Anything
#      tracked or untracked-but-not-ignored is left alone, which is what keeps a
#      committed build/ or vendored Pods/ safe.
#   2. Outside a repo, the name must be on the always-regenerable list below.
# Plus staleness: nothing is removed unless its newest depth-1 entry is older
# than --age days, so an in-flight build is never pulled out from under itself.
#
# Env: ROOTS (space-separated scan roots), AGE_DAYS, INSTALL_AGE_DAYS, NIX_KEEP.
# Designed to be callable from a launchd user agent; logs to stdout/stderr.

set -euo pipefail

AGE_DAYS="${AGE_DAYS:-30}"
# node_modules and Pods are the slow ones to rebuild (a full install, often over
# a metered link), so they wait considerably longer than compiler output does.
INSTALL_AGE_DAYS="${INSTALL_AGE_DAYS:-180}"
NIX_KEEP="${NIX_KEEP:-14d}"
APPLY=0
DEEP=0
VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --deep) DEEP=1 ;;
    -v|--verbose) VERBOSE=1 ;;
    --age) AGE_DAYS="$2"; shift ;;
    --age=*) AGE_DAYS="${1#*=}" ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

# ~/Developer is the real project tree; the two worktree dirs are where Herdr
# and Claude check out throwaway branches, and they accumulate their own
# node_modules and target/ copies. Scanning them reclaims that without touching
# the worktrees themselves, which may hold another agent's uncommitted work.
read -r -a SCAN_ROOTS <<<"${ROOTS:-$HOME/Developer $HOME/.herdr/worktrees $HOME/.claude-worktrees}"

# Regenerable regardless of git status. `target` additionally requires a sibling
# Cargo.toml; `build` is deliberately absent because plenty of projects commit
# into one, so it only qualifies via the git-ignored path.
ALWAYS_SAFE='node_modules|target|.next|.turbo|.expo|Pods|DerivedData|.gradle|.venv|__pycache__|.parcel-cache|.dart_tool|.cxx'

# Pinned to the system tools: PATH here may put GNU coreutils and bfs ahead of
# /usr/bin, and their stat format flags and find semantics differ from BSD's.
FIND=/usr/bin/find
STAT=/usr/bin/stat
DU=/usr/bin/du

NOW=$(date +%s)
freed_kb=0
declare -a plan=()

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }

human() {
  awk -v k="${1:-0}" 'BEGIN{
    if (k >= 1048576) printf "%.1f GB", k/1048576;
    else if (k >= 1024) printf "%.0f MB", k/1024;
    else printf "%d KB", k;
  }'
}

dir_kb() { "$DU" -sxk "$1" 2>/dev/null | awk '{print $1}'; }

# Age of the most recently touched depth-1 entry. A build always writes a child
# (target/debug, node_modules/.package-lock.json), while the parent's own mtime
# can sit unchanged for months, so the parent alone is not a usable signal.
newest_age_days() {
  local newest
  newest=$("$FIND" "$1" -maxdepth 1 -exec "$STAT" -f '%m' {} + 2>/dev/null | sort -rn | head -1)
  [[ "$newest" =~ ^[0-9]+$ ]] || { echo 99999; return; }
  echo $(( (NOW - newest) / 86400 ))
}

# 0 = ignored, 1 = tracked or visible to git, 2 = not a repo at all.
git_ignored() {
  local parent; parent=$(dirname "$1")
  git -C "$parent" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 2
  git -C "$parent" check-ignore -q "$1" 2>/dev/null
}

# queue LABEL PATH — size it, record it, and delete when --apply is set.
queue() {
  local label="$1" path="$2" kb
  [[ -e "$path" ]] || return 0
  kb=$(dir_kb "$path"); [[ -z "$kb" || "$kb" -lt 1024 ]] && return 0
  freed_kb=$(( freed_kb + kb ))
  plan+=("$kb|$label|${path/#$HOME/~}")
  if (( APPLY )); then
    if ! rm -rf -- "$path" 2>/dev/null; then
      chmod -R u+w -- "$path" 2>/dev/null || true
      rm -rf -- "$path" 2>/dev/null || log "failed to remove $path"
    fi
  fi
}

# run_cmd LABEL DIR CMD... — for tools that prune their own cache. Sizes DIR
# before and after so the accounting matches the deletes above.
run_cmd() {
  local label="$1" dir="$2"; shift 2
  command -v "$1" >/dev/null 2>&1 || return 0
  [[ -d "$dir" ]] || return 0
  local before after=0
  before=$(dir_kb "$dir")
  (( ${before:-0} >= 1024 )) || return 0
  if (( APPLY )); then
    "$@" >/dev/null 2>&1 || log "$label: $1 exited nonzero, continuing"
    [[ -d "$dir" ]] && after=$(dir_kb "$dir")
    local delta=$(( before - after ))
    (( delta > 0 )) || return 0
    freed_kb=$(( freed_kb + delta ))
    plan+=("$delta|$label|$*")
  else
    plan+=("$before|$label|$*")
  fi
}

echo
echo "mac-storage-gc — $( ((APPLY)) && echo APPLY || echo 'dry run, pass --apply to delete') | stale after ${AGE_DAYS}d, installs after ${INSTALL_AGE_DAYS}d"
df -h / | tail -1 | awk '{printf "before: %s used of %s, %s free\n", $3, $2, $4}'
echo

### 1. Build artifacts under the project trees

for root in "${SCAN_ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r -d '' dir; do
    name=$(basename "$dir")

    rc=0; git_ignored "$dir" || rc=$?
    case $rc in
      0) ;;                                             # git-ignored: fair game
      1) continue ;;                                    # git can see it: leave it
      2) [[ "$name" =~ ^(${ALWAYS_SAFE})$ ]] || continue ;;
    esac

    # A bare `target` outside Cargo is somebody else's output directory.
    if [[ "$name" == target && ! -f "$(dirname "$dir")/Cargo.toml" ]]; then
      continue
    fi

    cutoff=$AGE_DAYS
    [[ "$name" == node_modules || "$name" == Pods ]] && cutoff=$INSTALL_AGE_DAYS
    (( $(newest_age_days "$dir") >= cutoff )) || continue
    queue "$name" "$dir"
  done < <(
    "$FIND" "$root" \
      -type d -name .git -prune -o \
      -type d \( -name node_modules -o -name target -o -name build \
                 -o -name .next -o -name .turbo -o -name .expo -o -name Pods \
                 -o -name DerivedData -o -name .gradle -o -name .venv \
                 -o -name __pycache__ -o -name .parcel-cache -o -name .dart_tool \
                 -o -name .cxx \
              \) -prune -print0 2>/dev/null
  )
done

### 2. Xcode and iOS tooling

queue "xcode-derived" "$HOME/Library/Developer/Xcode/DerivedData"
queue "xcode-modcache" "$HOME/Library/Developer/Xcode/ModuleCache.noindex"
queue "simulator-cache" "$HOME/Library/Developer/CoreSimulator/Caches"
queue "swiftpm-cache" "$HOME/Library/Caches/org.swift.swiftpm"
queue "cocoapods-cache" "$HOME/Library/Caches/CocoaPods"

# DeviceSupport is re-created the next time each device is plugged in, but that
# costs a slow first connect, so it only goes in --deep. Newest two are kept.
if (( DEEP )) && [[ -d "$HOME/Library/Developer/Xcode/iOS DeviceSupport" ]]; then
  while IFS= read -r d; do
    queue "ios-devicesupport" "$d"
  done < <(/bin/ls -dt "$HOME/Library/Developer/Xcode/iOS DeviceSupport"/* 2>/dev/null | tail -n +3)
fi

### 3. Package manager caches

run_cmd "homebrew" "$HOME/Library/Caches/Homebrew" brew cleanup -s --prune=all
run_cmd "npm" "$HOME/.npm/_cacache" npm cache clean --force
run_cmd "yarn" "$HOME/.yarn/berry/cache" yarn cache clean --all
run_cmd "uv" "$HOME/.cache/uv" uv cache prune

# `npm cache clean` leaves _npx alone, and it is by far the larger of the two.
queue "npx-cache" "$HOME/.npm/_npx"
queue "pnpm-store" "$HOME/Library/pnpm/store"
queue "bun-cache" "$HOME/.bun/install/cache"
run_cmd "go-build" "$HOME/Library/Caches/go-build" go clean -cache
if (( DEEP )); then run_cmd "go-modcache" "$HOME/go/pkg/mod" go clean -modcache; fi

queue "cargo-registry" "$HOME/.cargo/registry/cache"
queue "cargo-src" "$HOME/.cargo/registry/src"
queue "cargo-git" "$HOME/.cargo/git/checkouts"
queue "electron-cache" "$HOME/Library/Caches/electron"
queue "electron-builder" "$HOME/Library/Caches/electron-builder"
queue "dotslash-cache" "$HOME/Library/Caches/dotslash"

### 4. Nix

# --delete-older-than, never -d: -d drops every rollback generation, and losing
# the ability to boot the previous system is not worth a few GB.
if command -v nix-collect-garbage >/dev/null 2>&1; then
  nix_before=$(df -k /nix | tail -1 | awk '{print $3}')
  if (( APPLY )); then
    log "nix gc: user profiles older than $NIX_KEEP"
    nix-collect-garbage --delete-older-than "$NIX_KEEP" >/dev/null 2>&1 || log "user nix gc failed"
    log "nix gc: system profiles older than $NIX_KEEP"
    sudo -n nix-collect-garbage --delete-older-than "$NIX_KEEP" >/dev/null 2>&1 || log "system nix gc needs sudo, skipped"
    nix_after=$(df -k /nix | tail -1 | awk '{print $3}')
    delta=$(( nix_before - nix_after ))
    if (( delta > 0 )); then
      freed_kb=$(( freed_kb + delta ))
      plan+=("$delta|nix-store|generations older than $NIX_KEEP")
    fi
  else
    gens=$( (sudo -n nix-env -p /nix/var/nix/profiles/system --list-generations 2>/dev/null || true) | wc -l | tr -d ' ')
    log "nix: $gens system generations on disk, gc would keep the last $NIX_KEEP"
  fi
fi

### Report

if (( ${#plan[@]} == 0 )); then
  echo "nothing to reclaim."
else
  # Grouped by kind: one project tree can contribute a hundred lines, and the
  # useful question is which category is holding the space.
  printf '%s\n' "${plan[@]}" \
    | awk -F'|' '{ kb[$2] += $1; n[$2]++ } END { for (l in kb) printf "%d\t%s\t%d\n", kb[l], l, n[l] }' \
    | sort -rn \
    | while IFS=$'\t' read -r kb label n; do
        printf '%10s  %-18s %s\n' "$(human "$kb")" "$label" "$( ((n>1)) && echo "$n items" || true)"
      done

  if (( VERBOSE )); then
    echo
    printf '%s\n' "${plan[@]}" | sort -rn -t'|' -k1,1 \
      | while IFS='|' read -r kb label path; do
          printf '%10s  %-18s %s\n' "$(human "$kb")" "$label" "$path"
        done
  fi

  echo
  printf '%s %s\n' "$( ((APPLY)) && echo 'reclaimed:' || echo 'reclaimable:')" "$(human "$freed_kb")"
fi

echo
df -h / | tail -1 | awk '{printf "after:  %s used of %s, %s free\n", $3, $2, $4}'

### Manual review — sized, never touched

echo
echo "not touched, decide by hand:"
for p in \
  "$HOME/Library/Developer/CoreSimulator/Devices" \
  "$HOME/Library/Android" \
  "$HOME/.android/avd" \
  "$HOME/Movies" \
  "$HOME/Library/Messages" \
  "$HOME/Library/Application Support/Spotify" \
  "$HOME/Library/Application Support/Claude"
do
  [[ -e "$p" ]] || continue
  printf '%10s  %s\n' "$(human "$(dir_kb "$p")")" "${p/#$HOME/~}"
done

if (( APPLY )); then
  /usr/bin/osascript -e "display notification \"Reclaimed $(human "$freed_kb")\" with title \"Storage cleanup\"" >/dev/null 2>&1 || true
fi
