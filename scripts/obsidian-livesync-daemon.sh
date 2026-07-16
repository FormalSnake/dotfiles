#!/usr/bin/env bash
# Headless LiveSync daemon (macbook). Renders the CLI's settings from agenix
# secrets (once — the CLI rewrites the file after first run), then execs the
# self-hosted-livesync CLI in daemon mode so ~/Notes stays current off CouchDB's
# _changes feed without the Obsidian GUI open. Launched by launchd (KeepAlive).
#
# Prereqs, done once by the owner: build the CLI (obsidian-livesync-cli-build.sh)
# and create secrets/livesync-passphrase.age. Until both exist this self-throttles
# (logs why, exits 0) instead of crash-looping. The exact CLI invocation below is
# per the design research and should be confirmed against the first real run.
set -uo pipefail

VAULT="$HOME/Notes"
STATE="${LIVESYNC_STATE_DIR:-$HOME/.local/state/livesync}"   # DB/state + settings live OUTSIDE the vault so secrets never sync
CLI="${LIVESYNC_CLI_DIR:-$HOME/.local/share/livesync-cli}/src/apps/cli/dist/index.cjs"
SETTINGS="$STATE/.livesync/settings.json"
PW_FILE="${COUCHDB_ADMIN_SECRET_FILE:-/run/agenix/couchdb-admin}"
PASS_FILE="${LIVESYNC_PASSPHRASE_FILE:-/run/agenix/livesync-passphrase}"

miss() { echo "$(date -Iseconds) $1 — daemon idle"; sleep 30; exit 0; }
[ -f "$CLI" ]       || miss "CLI not built ($CLI); run obsidian-livesync-cli-build.sh"
[ -r "$PW_FILE" ]   || miss "missing $PW_FILE"
[ -r "$PASS_FILE" ] || miss "missing $PASS_FILE (create secrets/livesync-passphrase.age)"

# Seed settings only when absent: the CLI migrates couchDB_* into its own
# connection-string form after first run, so re-rendering every start would fight it.
if [ ! -f "$SETTINGS" ]; then
  mkdir -p "$STATE/.livesync"
  PW=$(cat "$PW_FILE"); PASS=$(cat "$PASS_FILE")
  ( umask 177; cat > "$SETTINGS" <<EOF
{
  "couchDB_URI": "http://127.0.0.1:5984",
  "couchDB_USER": "admin",
  "couchDB_PASSWORD": "$PW",
  "couchDB_DBNAME": "notes",
  "encrypt": true,
  "passphrase": "$PASS",
  "liveSync": true,
  "isConfigured": true
}
EOF
  )
  echo "$(date -Iseconds) seeded $SETTINGS"
fi

echo "$(date -Iseconds) starting daemon: node $CLI $STATE --vault $VAULT"
exec node "$CLI" "$STATE" --vault "$VAULT"
