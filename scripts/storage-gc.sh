#!/usr/bin/env bash
# Reclaim disk on the macbook and the NixOS hosts by deleting only things one
# command regenerates: stale build artifacts, package-manager caches, Xcode
# derived data (mac), and old nix generations (mac; NixOS runs nix.gc itself).
# Nothing here touches source, media, or app data.
#
# Dry run by default. Pass --apply to delete.
#
#   storage-gc.sh                      what would go, plus the manual-review list
#   storage-gc.sh --apply              delete it
#   storage-gc.sh --apply --age 7      more aggressive staleness cutoff
#   storage-gc.sh --apply --deep       also Go modcache and old iOS DeviceSupport
#
# Two safety rules gate every directory delete:
#   1. Inside a git work tree, the directory must be git-ignored. Anything
#      tracked or untracked-but-not-ignored is left alone, which is what keeps a
#      committed build/ or vendored Pods/ safe.
#   2. Outside a repo, the name must be on the always-regenerable list below.
# Plus staleness: nothing is removed unless its newest depth-1 entry is older
# than --age days, so an in-flight build is never pulled out from under itself.
#
# Low-free-space mode: when / has less than LOW_FREE_GB free (default 30), every
# cutoff is divided by 4 (minimum 1 day) so a full disk is cleared in one pass.
#
# Env: ROOTS (space-separated scan roots), AGE_DAYS, TARGET_AGE_DAYS,
# WORKTREE_AGE_DAYS, INSTALL_AGE_DAYS, NIX_KEEP, LOW_FREE_GB.
# Callable from a launchd user agent (mac) or a systemd service (NixOS); logs
# to stdout/stderr.

set -euo pipefail

AGE_DAYS="${AGE_DAYS:-30}"
# node_modules and Pods are the slow ones to rebuild (a full install, often over
# a metered link), so they wait considerably longer than compiler output does.
INSTALL_AGE_DAYS="${INSTALL_AGE_DAYS:-180}"
# Cargo output is the fast one to regrow and the fast one to rebuild: one debug
# target/ of the Rust monorepo passes 50 GB in a week, so it goes sooner.
TARGET_AGE_DAYS="${TARGET_AGE_DAYS:-7}"
# Agent worktrees (Claude, Herdr) each carry a full copy of that target/ and
# are abandoned within days of being created. Sep 2026: seven of them filled
# 90 GB between two weekly runs.
WORKTREE_AGE_DAYS="${WORKTREE_AGE_DAYS:-3}"
NIX_KEEP="${NIX_KEEP:-14d}"
LOW_FREE_GB="${LOW_FREE_GB:-30}"
OS=$(uname -s)
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
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

LOW_FREE=0
free_gb=$(df -Pk / | awk 'NR==2 {printf "%d", $4/1048576}')
if (( free_gb < LOW_FREE_GB )); then
  LOW_FREE=1
  for v in AGE_DAYS INSTALL_AGE_DAYS TARGET_AGE_DAYS WORKTREE_AGE_DAYS; do
    n=$(( ${!v} / 4 )); (( n >= 1 )) || n=1
    printf -v "$v" '%s' "$n"
  done
fi

# ~/Developer is the real project tree; the two worktree dirs are where Herdr
# and Claude check out throwaway branches, and they accumulate their own
# node_modules and target/ copies. Scanning them reclaims that without touching
# the worktrees themselves, which may hold another agent's uncommitted work.
read -r -a SCAN_ROOTS <<<"${ROOTS:-$HOME/Developer $HOME/.herdr/worktrees $HOME/.claude-worktrees}"
WORKTREE_PATH='/\.claude/worktrees/|/\.herdr/worktrees/|/\.claude-worktrees/'

# Regenerable regardless of git status. `target` additionally requires a sibling
# Cargo.toml; `build` is deliberately absent because plenty of projects commit
# into one, so it only qualifies via the git-ignored path.
# `.build` (SwiftPM) needs a sibling Package.swift, `.zig-cache` and `zig-out`
# a sibling build.zig, same as `target` and Cargo.toml.
ALWAYS_SAFE='node_modules|target|.next|.turbo|.expo|Pods|DerivedData|.gradle|.venv|__pycache__|.parcel-cache|.dart_tool|.cxx|.build|.zig-cache|zig-out'

# On the mac, pinned to the system tools: PATH there may put GNU coreutils and
# bfs ahead of /usr/bin, and their stat format flags and find semantics differ
# from BSD's. On Linux the GNU tools are the system tools.
if [[ "$OS" == Darwin ]]; then
  FIND=/usr/bin/find
  STAT=/usr/bin/stat
  DU=/usr/bin/du
  STAT_MTIME=(-f '%m')
else
  FIND=find
  STAT=stat
  DU=du
  STAT_MTIME=(-c '%Y')
fi

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
  newest=$("$FIND" "$1" -maxdepth 1 -exec "$STAT" "${STAT_MTIME[@]}" {} + 2>/dev/null | sort -rn | head -1)
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
echo "storage-gc ($OS) — $( ((APPLY)) && echo APPLY || echo 'dry run, pass --apply to delete')$( ((LOW_FREE)) && echo " | LOW FREE (${free_gb} GB < ${LOW_FREE_GB} GB), cutoffs cut to a quarter") | stale after ${AGE_DAYS}d, target ${TARGET_AGE_DAYS}d, worktrees ${WORKTREE_AGE_DAYS}d, installs ${INSTALL_AGE_DAYS}d"
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

    # A bare `target`, `.build` or `zig-out` outside its build system is
    # somebody else's output directory.
    parent=$(dirname "$dir")
    case "$name" in
      target) [[ -f "$parent/Cargo.toml" ]] || continue ;;
      .build) [[ -f "$parent/Package.swift" ]] || continue ;;
      .zig-cache|zig-out) [[ -f "$parent/build.zig" ]] || continue ;;
    esac

    cutoff=$AGE_DAYS
    [[ "$name" == node_modules || "$name" == Pods ]] && cutoff=$INSTALL_AGE_DAYS
    [[ "$name" == target || "$name" == .build || "$name" == .zig-cache || "$name" == zig-out ]] && cutoff=$TARGET_AGE_DAYS
    [[ "$dir" =~ $WORKTREE_PATH ]] && cutoff=$WORKTREE_AGE_DAYS
    (( $(newest_age_days "$dir") >= cutoff )) || continue
    queue "$name" "$dir"
  done < <(
    "$FIND" "$root" \
      -type d -name .git -prune -o \
      -type d \( -name node_modules -o -name target -o -name build \
                 -o -name .next -o -name .turbo -o -name .expo -o -name Pods \
                 -o -name DerivedData -o -name .gradle -o -name .venv \
                 -o -name __pycache__ -o -name .parcel-cache -o -name .dart_tool \
                 -o -name .cxx -o -name .build -o -name .zig-cache \
                 -o -name zig-out \
              \) -prune -print0 2>/dev/null
  )
done

### 2. Xcode and iOS tooling

if [[ "$OS" == Darwin ]]; then
  queue "xcode-derived" "/Volumes/Kyan Drive/DerivedData"
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
fi

### 3. Nix VM scratch

# nixos-rebuild's linux-builder and the FormalShell test VM each unpack a
# store image into $TMPDIR/nix-vm.XXXX and only remove it on a clean exit. A
# killed VM leaves 8 GB behind. Anything no running qemu still names is dead.
for d in "${TMPDIR:-/tmp}"/nix-vm.*; do
  [[ -d "$d" ]] || continue
  pgrep -f "$(basename "$d")" >/dev/null 2>&1 && continue
  (( $(newest_age_days "$d") >= 1 )) || continue
  queue "nix-vm-scratch" "$d"
done

### 4. Package manager caches

[[ "$OS" == Darwin ]] && run_cmd "homebrew" "$HOME/Library/Caches/Homebrew" brew cleanup -s --prune=all
run_cmd "npm" "$HOME/.npm/_cacache" npm cache clean --force
run_cmd "yarn" "$HOME/.yarn/berry/cache" yarn cache clean --all
run_cmd "uv" "$HOME/.cache/uv" uv cache prune

# `npm cache clean` leaves _npx alone, and it is by far the larger of the two.
queue "npx-cache" "$HOME/.npm/_npx"
queue "bun-cache" "$HOME/.bun/install/cache"
if [[ "$OS" == Darwin ]]; then
  queue "pnpm-store" "$HOME/Library/pnpm/store"
  run_cmd "go-build" "$HOME/Library/Caches/go-build" go clean -cache
else
  queue "pnpm-store" "${XDG_DATA_HOME:-$HOME/.local/share}/pnpm/store"
  queue "bun-cache" "${XDG_CACHE_HOME:-$HOME/.cache}/bun/install/cache"
  run_cmd "go-build" "${XDG_CACHE_HOME:-$HOME/.cache}/go-build" go clean -cache
fi
if (( DEEP )); then run_cmd "go-modcache" "$HOME/go/pkg/mod" go clean -modcache; fi

# cargo-cache prunes the registry by itself when installed; otherwise the
# documented dirs go, same as on the mac.
if [[ "$OS" != Darwin ]] && command -v cargo-cache >/dev/null 2>&1; then
  run_cmd "cargo-cache" "$HOME/.cargo/registry" cargo-cache --autoclean
else
  queue "cargo-registry" "$HOME/.cargo/registry/cache"
  queue "cargo-src" "$HOME/.cargo/registry/src"
fi
queue "cargo-git" "$HOME/.cargo/git/checkouts"

if [[ "$OS" == Darwin ]]; then
  queue "electron-cache" "$HOME/Library/Caches/electron"
  queue "electron-builder" "$HOME/Library/Caches/electron-builder"
  queue "dotslash-cache" "$HOME/Library/Caches/dotslash"
else
  # The native-desktop CLI builds its host crates here; same regrowth as any
  # cargo target/, so it follows the target cutoff.
  nd_target="${XDG_CACHE_HOME:-$HOME/.cache}/nd-build/target"
  if [[ -d "$nd_target" ]] && (( $(newest_age_days "$nd_target") >= TARGET_AGE_DAYS )); then
    queue "nd-build-target" "$nd_target"
  fi
  queue "electron-cache" "${XDG_CACHE_HOME:-$HOME/.cache}/electron"
  queue "electron-builder" "${XDG_CACHE_HOME:-$HOME/.cache}/electron-builder"
fi

### 5. Nix

# --delete-older-than, never -d: -d drops every rollback generation, and losing
# the ability to boot the previous system is not worth a few GB.
# NixOS hosts run nix.gc daily and keep three generations (nixos/mixins/nix.nix),
# so this pass is mac-only.
if [[ "$OS" == Darwin ]] && command -v nix-collect-garbage >/dev/null 2>&1; then
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
if [[ "$OS" == Darwin ]]; then
  review=(
    "$HOME/Library/Developer/CoreSimulator/Devices"
    "$HOME/Library/Android"
    "$HOME/.android/avd"
    "$HOME/Movies"
    "$HOME/Library/Messages"
    "$HOME/Library/Application Support/Spotify"
    "$HOME/Library/Application Support/Claude"
  )
else
  review=(
    "$HOME/.local/share/Steam"
    "$HOME/.local/share/flatpak"
    "$HOME/.android/avd"
    "$HOME/Videos"
  )
fi
for p in "${review[@]}"
do
  [[ -e "$p" ]] || continue
  printf '%10s  %s\n' "$(human "$(dir_kb "$p")")" "${p/#$HOME/~}"
done

if (( APPLY )) && [[ "$OS" == Darwin ]]; then
  /usr/bin/osascript -e "display notification \"Reclaimed $(human "$freed_kb")\" with title \"Storage cleanup\"" >/dev/null 2>&1 || true
fi
