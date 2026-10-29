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
#   storage-gc.sh --apply --prune-worktrees
#                                      also remove clean, untouched agent worktrees
#
# Two safety rules gate every directory delete:
#   1. Inside a git work tree, the directory must be git-ignored. Anything
#      tracked or untracked-but-not-ignored is left alone, which is what keeps a
#      committed build/ or vendored Pods/ safe.
#   2. Outside a repo, the name must be on the always-regenerable list below.
#   3. A directory carrying a CACHEDIR.TAG (cargo, sccache, zed) is a cache
#      whatever its name and wherever it sits, so a target/ that an agent
#      renamed or pointed elsewhere still counts.
# Plus staleness: nothing is removed unless its newest depth-1 entry is older
# than --age days, so an in-flight build is never pulled out from under itself.
#
# Agent worktrees (.claude/worktrees, .herdr/worktrees, .claude-worktrees) are
# only emptied of build output by default. --prune-worktrees also removes the
# worktree itself when `git status` is clean and nothing in it was touched for
# WORKTREE_PRUNE_AGE_DAYS; the branch stays. A dirty worktree is never touched.
#
# Agent test runs leave their screenshots and logs in loose directories next
# to the repos (nd-rel-058-runs, polish-shots, bench-rvs-mac, ti-gates): not
# a git repo, named *-runs, *-shots, *-gates or bench-*, and never looked at
# again once the task is over. They go after RUNS_AGE_DAYS.
#
# VM disks a dev script boots (dev/.linux-builder, dev/.testvm) go once no
# qemu names them and they sat idle for the stale cutoff.
#
# `result` links left by nix build and the justfile's build recipe are GC
# roots: one forgotten ~/.config/nix/result pinned a 42 GB system closure on
# the g815 (Oct 2026). Links older than the target cutoff are unlinked so the
# next collection can reap what they held; the build output is one command
# away.
#
# Low-free-space mode: when / has less than LOW_FREE_GB free (default 30), every
# cutoff is divided by 4 (minimum 1 day) so a full disk is cleared in one pass,
# and compiler output (target/, worktree build dirs, fspec builds) goes once it
# sat idle for PRESSURE_HOURS. Day-based cutoffs never fire during active work:
# Oct 2026, four kopuz-gpui worktrees built 26 GB of target/ in one day.
#
# Env: ROOTS (space-separated scan roots), AGE_DAYS, TARGET_AGE_DAYS,
# WORKTREE_AGE_DAYS, WORKTREE_PRUNE_AGE_DAYS, RUNS_AGE_DAYS, INSTALL_AGE_DAYS,
# NIX_KEEP, LOW_FREE_GB, PRESSURE_HOURS.
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
# A clean worktree nobody opened in two weeks is finished work; its branch
# keeps the commits. Oct 2026: 83 of them under one repo's .claude/worktrees.
WORKTREE_PRUNE_AGE_DAYS="${WORKTREE_PRUNE_AGE_DAYS:-14}"
# Run artifacts are read within hours of the run or never. Oct 2026: 42 such
# dirs on the g815, 15 GB, the oldest from July, none opened since.
RUNS_AGE_DAYS="${RUNS_AGE_DAYS:-7}"
NIX_KEEP="${NIX_KEEP:-14d}"
LOW_FREE_GB="${LOW_FREE_GB:-30}"
PRESSURE_HOURS="${PRESSURE_HOURS:-6}"
OS=$(uname -s)
APPLY=0
DEEP=0
PRUNE_WORKTREES=0
VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --deep) DEEP=1 ;;
    --prune-worktrees) PRUNE_WORKTREES=1 ;;
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
  for v in AGE_DAYS INSTALL_AGE_DAYS TARGET_AGE_DAYS WORKTREE_AGE_DAYS WORKTREE_PRUNE_AGE_DAYS RUNS_AGE_DAYS; do
    n=$(( ${!v} / 4 )); (( n >= 1 )) || n=1
    printf -v "$v" '%s' "$n"
  done
fi
TARGET_CUT_H=$(( TARGET_AGE_DAYS * 24 ))
WORKTREE_CUT_H=$(( WORKTREE_AGE_DAYS * 24 ))
if (( LOW_FREE )); then
  TARGET_CUT_H=$PRESSURE_HOURS
  WORKTREE_CUT_H=$PRESSURE_HOURS
fi

# ~/Developer is the real project tree; the two worktree dirs are where Herdr
# and Claude check out throwaway branches, and they accumulate their own
# node_modules and target/ copies. Scanning them reclaims that without touching
# the worktrees themselves, which may hold another agent's uncommitted work.
# dev-cache.noindex on the external SSD is where the nativedesktop worktrees
# point their cargo target dirs (per-worktree .cargo/config.toml), next to the
# CEF downloads, sccache and zed caches; it is dev overflow on a drive meant
# for personal data, so it is swept as hard as ~/Developer.
if [[ -n "${ROOTS:-}" ]]; then
  read -r -a SCAN_ROOTS <<<"$ROOTS"
else
  # ~/build is where agents point CARGO_TARGET_DIR and drop screenshot runs;
  # fspec's per-package build dirs hold a cargo target each.
  SCAN_ROOTS=("$HOME/Developer" "$HOME/.herdr/worktrees" "$HOME/.claude-worktrees" "$HOME/build" "${XDG_CACHE_HOME:-$HOME/.cache}/fspec/build")
  [[ "$OS" == Darwin ]] && SCAN_ROOTS+=("/Volumes/Kyan Drive/dev-cache.noindex")
fi
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
newest_age_hours() {
  local newest
  newest=$("$FIND" "$1" -maxdepth 1 -exec "$STAT" "${STAT_MTIME[@]}" {} + 2>/dev/null | sort -rn | head -1)
  [[ "$newest" =~ ^[0-9]+$ ]] || { echo 999999; return; }
  echo $(( (NOW - newest) / 3600 ))
}
newest_age_days() { echo $(( $(newest_age_hours "$1") / 24 )); }

# cargo writes this tag into every target dir it creates.
is_cachedir() {
  head -c 43 "$1/CACHEDIR.TAG" 2>/dev/null | grep -q '^Signature: 8a477f597d28d172789f06886806bc55'
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
echo "storage-gc ($OS) — $( ((APPLY)) && echo APPLY || echo 'dry run, pass --apply to delete')$( ((LOW_FREE)) && echo " | LOW FREE (${free_gb} GB < ${LOW_FREE_GB} GB), cutoffs cut to a quarter") | stale after ${AGE_DAYS}d, target ${TARGET_CUT_H}h, worktrees ${WORKTREE_CUT_H}h, installs ${INSTALL_AGE_DAYS}d"
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
      2) [[ "$name" =~ ^(${ALWAYS_SAFE})$ ]] || is_cachedir "$dir" || continue ;;
    esac

    # A bare `target`, `.build` or `zig-out` outside its build system is
    # somebody else's output directory, unless cargo tagged it (a relocated
    # CARGO_TARGET_DIR, fspec's build/).
    parent=$(dirname "$dir")
    case "$name" in
      target) [[ -f "$parent/Cargo.toml" ]] || is_cachedir "$dir" || continue ;;
      .build) [[ -f "$parent/Package.swift" ]] || continue ;;
      .zig-cache|zig-out) [[ -f "$parent/build.zig" ]] || continue ;;
    esac

    # A VM disk still attached to a qemu is in use whatever its mtime says.
    case "$name" in
      .linux-builder|.testvm) pgrep -f "$dir" >/dev/null 2>&1 && continue ;;
    esac

    cutoff=$(( AGE_DAYS * 24 ))
    [[ "$name" == node_modules || "$name" == Pods ]] && cutoff=$(( INSTALL_AGE_DAYS * 24 ))
    [[ "$name" == target || "$name" == .build || "$name" == .zig-cache || "$name" == zig-out ]] && cutoff=$TARGET_CUT_H
    is_cachedir "$dir" && cutoff=$TARGET_CUT_H
    [[ "$dir" =~ $WORKTREE_PATH ]] && cutoff=$WORKTREE_CUT_H
    (( $(newest_age_hours "$dir") >= cutoff )) || continue
    queue "$name" "$dir"
  done < <(
    "$FIND" "$root" -mindepth 1 \
      -type d -name .git -prune -o \
      -type d \( -name node_modules -o -name target -o -name build \
                 -o -name .next -o -name .turbo -o -name .expo -o -name Pods \
                 -o -name DerivedData -o -name .gradle -o -name .venv \
                 -o -name __pycache__ -o -name .parcel-cache -o -name .dart_tool \
                 -o -name .cxx -o -name .build -o -name .zig-cache \
                 -o -name zig-out -o -name .linux-builder -o -name .testvm \
              \) -prune -print0 2>/dev/null
  )

  # Rule 3: anything tagged as a cache dir, whatever it is called. cargo
  # writes the tag into every target dir, so a `clean-a-target` next to a
  # worktree, or a target dir relocated by CARGO_TARGET_DIR, is caught here.
  # The named dirs above are pruned from this walk so nothing queues twice.
  while IFS= read -r -d '' tag; do
    dir=$(dirname "$tag")
    is_cachedir "$dir" || continue
    rc=0; git_ignored "$dir" || rc=$?
    (( rc == 1 )) && continue
    (( $(newest_age_hours "$dir") >= TARGET_CUT_H )) || continue
    queue "cachedir-tag" "$dir"
  done < <(
    "$FIND" "$root" -mindepth 1 \
      -type d \( -name .git -o -name node_modules -o -name target -o -name build \
                 -o -name .next -o -name .turbo -o -name .expo -o -name Pods \
                 -o -name DerivedData -o -name .gradle -o -name .venv \
                 -o -name __pycache__ -o -name .parcel-cache -o -name .dart_tool \
                 -o -name .cxx -o -name .build -o -name .zig-cache \
                 -o -name zig-out -o -name .linux-builder -o -name .testvm \
              \) -prune -o \
      -type f -name CACHEDIR.TAG -print0 2>/dev/null
  )
done

### 1b. Agent run artifacts

# Depth 1 under the scan roots and the home dir. A directory that is a git
# repo, or sits inside one, is somebody's checkout whatever its name.
for root in "${SCAN_ROOTS[@]}" "$HOME"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r -d '' dir; do
    name=$(basename "$dir")
    [[ "$name" =~ (-runs[0-9]*|-shots|-macshots|-gates)$ || "$name" =~ ^bench- ]] || continue
    [[ -e "$dir/.git" ]] && continue
    git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 && continue
    (( $(newest_age_days "$dir") >= RUNS_AGE_DAYS )) || continue
    queue "agent-runs" "$dir"
  done < <("$FIND" "$root" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
done

### 1c. Agent worktrees that are finished

# Only the dirs agents create for themselves. Worktrees the owner checked out
# directly under ~/Developer are never candidates. `git worktree remove`
# without --force is the second guard: it refuses anything with modified or
# untracked files, so a dirty tree survives even if the status check raced.
if (( PRUNE_WORKTREES )); then
  for root in "${SCAN_ROOTS[@]}"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r -d '' wt; do
      [[ "$wt" =~ $WORKTREE_PATH ]] || continue
      [[ -f "$wt/.git" ]] || continue
      [[ -z "$(git -C "$wt" status --porcelain 2>/dev/null)" ]] || continue
      git -C "$wt" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
      (( $(newest_age_days "$wt") >= WORKTREE_PRUNE_AGE_DAYS )) || continue
      kb=$(dir_kb "$wt"); [[ -z "$kb" ]] && continue
      main=$(git -C "$wt" rev-parse --git-common-dir 2>/dev/null)
      if (( APPLY )); then
        git -C "$main" worktree remove "$wt" >/dev/null 2>&1 || { log "kept $wt: git refused to remove it"; continue; }
        git -C "$main" worktree prune >/dev/null 2>&1 || true
      fi
      freed_kb=$(( freed_kb + kb ))
      plan+=("$kb|stale-worktree|${wt/#$HOME/~}")
    done < <(
      "$FIND" "$root" -mindepth 1 -maxdepth 6 -type d \( -path '*/.claude/worktrees/*' -o -path '*/.herdr/worktrees/*' -o -path '*/.claude-worktrees/*' \) -prune -print0 2>/dev/null
    )
  done
fi

### 2. Xcode and iOS tooling

if [[ "$OS" == Darwin ]]; then
  queue "xcode-derived" "/Volumes/Kyan Drive/DerivedData"
  queue "xcode-modcache" "$HOME/Library/Developer/Xcode/ModuleCache.noindex"
  queue "simulator-cache" "$HOME/Library/Developer/CoreSimulator/Caches"
  # Devices whose runtime is gone keep their disk image until deleted. Each
  # one goes through simctl rather than rm so CoreSimulator's device list
  # stays consistent.
  if command -v xcrun >/dev/null 2>&1; then
    while IFS= read -r udid; do
      [[ -n "$udid" ]] || continue
      dev="$HOME/Library/Developer/CoreSimulator/Devices/$udid"
      [[ -d "$dev" ]] || continue
      kb=$(dir_kb "$dev"); [[ -z "$kb" || "$kb" -lt 1024 ]] && continue
      if (( APPLY )); then
        xcrun simctl delete "$udid" >/dev/null 2>&1 || { log "simctl could not delete $udid"; continue; }
      fi
      freed_kb=$(( freed_kb + kb ))
      plan+=("$kb|simulator-unavail|${dev/#$HOME/~}")
    done < <(xcrun simctl list devices unavailable -j 2>/dev/null \
      | awk -F'"' '/"udid"/ {print $4}')
  fi
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

# Test runs and SwiftPM leave mkdtemp dirs in $TMPDIR behind (TemporaryDirectory.*,
# xfs-*, playwright profiles): 100k of them on the mac in Oct 2026, and Finder
# held $TMPDIR open and spun two cores re-enumerating it. Only empty ones go,
# and rmdir refuses anything that gained an entry since the scan.
tmp_root="${TMPDIR:-/tmp}"
[[ "$OS" == Darwin ]] && tmp_root=$(getconf DARWIN_USER_TEMP_DIR)
tmp_root=${tmp_root%/}
tmp_dirs=0
while IFS= read -r -d '' d; do
  if (( APPLY )); then rmdir -- "$d" 2>/dev/null || continue; fi
  tmp_dirs=$(( tmp_dirs + 1 ))
done < <("$FIND" "$tmp_root" -mindepth 1 -maxdepth 1 -type d -empty -mtime +0 -print0 2>/dev/null)
(( tmp_dirs > 0 )) && plan+=("0|tmp-empty-dirs|$tmp_dirs empty temp dirs")

# Chromium and CEF (ndshell's cefdev) leave a SingletonSocket dir per launch and
# never remove it when killed: 3.4k of them in Oct 2026. A dir is stale once no
# process holds its socket.
live_sockets=$(lsof -U -Fn 2>/dev/null | sed -n 's/^n//p' || true)
singleton_dirs=0
while IFS= read -r -d '' sock; do
  d=${sock%/SingletonSocket}
  grep -qxF -- "$sock" <<<"$live_sockets" && continue
  grep -qxF -- "/private$sock" <<<"$live_sockets" && continue
  if (( APPLY )); then
    rm -f -- "$sock" "$d/SingletonCookie" "$d/SingletonLock"
    rmdir -- "$d" 2>/dev/null || continue
  fi
  singleton_dirs=$(( singleton_dirs + 1 ))
done < <("$FIND" "$tmp_root" -mindepth 2 -maxdepth 2 -name SingletonSocket -type s -mtime +0 -print0 2>/dev/null)
(( singleton_dirs > 0 )) && plan+=("0|tmp-singleton-dirs|$singleton_dirs stale Chromium singleton dirs")

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
  # Streamed audio only; Spotify refills it as tracks play. 8.7 GB in Oct 2026.
  queue "spotify-cache" "$HOME/Library/Application Support/Spotify/PersistentCache"
  queue "electron-cache" "$HOME/Library/Caches/electron"
  queue "electron-builder" "$HOME/Library/Caches/electron-builder"
  queue "dotslash-cache" "$HOME/Library/Caches/dotslash"
else
  # The native-desktop CLI builds its host crates here; same regrowth as any
  # cargo target/, so it follows the target cutoff.
  nd_target="${XDG_CACHE_HOME:-$HOME/.cache}/nd-build/target"
  if [[ -d "$nd_target" ]] && (( $(newest_age_hours "$nd_target") >= TARGET_CUT_H )); then
    queue "nd-build-target" "$nd_target"
  fi
  # The CEF runtime nativedesktop downloads on first launch, 1.5 GB per copy.
  nd_cef="${XDG_CACHE_HOME:-$HOME/.cache}/nativedesktop/cef"
  if [[ -d "$nd_cef" ]] && (( $(newest_age_days "$nd_cef") >= AGE_DAYS )); then
    queue "nativedesktop-cef" "$nd_cef"
  fi
  queue "electron-cache" "${XDG_CACHE_HOME:-$HOME/.cache}/electron"
  queue "electron-builder" "${XDG_CACHE_HOME:-$HOME/.cache}/electron-builder"
fi

### 5. Nix

# Stale nix build result links, under the project trees and the flake repo.
# Only the symlink goes; whether the store paths follow is up to the next
# collection (below on the mac, nix-gc.service on NixOS), so no size is
# claimed here.
result_links=0
for root in "${SCAN_ROOTS[@]}" "$HOME/.config/nix"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r -d '' link; do
    [[ "$(readlink "$link")" == /nix/store/* ]] || continue
    (( $(( (NOW - $("$STAT" "${STAT_MTIME[@]}" "$link")) / 86400 )) >= TARGET_AGE_DAYS )) || continue
    (( APPLY )) && rm -f -- "$link"
    result_links=$(( result_links + 1 ))
  done < <("$FIND" "$root" -maxdepth 4 -type d -name .git -prune -o -type l \( -name result -o -name 'result-*' \) -print0 2>/dev/null)
done
(( result_links > 0 )) && plan+=("0|nix-result-link|$result_links stale build result links unpinned")

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
    "$HOME/Library/Application Support/Claude/vm_bundles"
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
