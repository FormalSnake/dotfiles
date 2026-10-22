#!/usr/bin/env bash
# One-time (idempotent) build of vrtmrz's self-hosted-livesync headless CLI on
# the macbook. Produces src/apps/cli/dist/index.cjs, which the launchd daemon
# (obsidian-livesync-daemon.sh) runs to keep ~/Notes current off CouchDB without
# the Obsidian GUI. node/npm come from the user profile (nodejs_24). Re-run to
# update. See docs/superpowers/specs/2026-07-16-obsidian-headless-livesync-design.md.
set -euo pipefail

DIR="${LIVESYNC_CLI_DIR:-$HOME/.local/share/livesync-cli}"
REPO="https://github.com/vrtmrz/obsidian-livesync"

if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull --ff-only
  git -C "$DIR" submodule update --init --recursive
else
  mkdir -p "$(dirname "$DIR")"
  git clone --recurse-submodules "$REPO" "$DIR"
fi

cd "$DIR"
npm ci
npm run build -w self-hosted-livesync-cli

CJS="$DIR/src/apps/cli/dist/index.cjs"
[ -f "$CJS" ] && echo "built: $CJS" || { echo "build produced no $CJS — check the CLI's build output path" >&2; exit 1; }
