#!/usr/bin/env bash
# One-time CouchDB config for Obsidian Self-hosted LiveSync (macbook).
# Appends a marked block to local.ini; CouchDB hashes the [admins] password
# in place on next start (that's why nix must NOT own this file).
# COUCHDB_ADMIN_SECRET_FILE overrides the password source (default: agenix).
set -euo pipefail

SECRET="${COUCHDB_ADMIN_SECRET_FILE:-/run/agenix/couchdb-admin}"
[ -r "$SECRET" ] || { echo "missing $SECRET — rebuild with the agenix change first" >&2; exit 1; }
PW=$(cat "$SECRET")

PREFIX=$(brew --prefix)
INI="$PREFIX/etc/couchdb/local.ini"
[ -f "$INI" ] || INI="$PREFIX/etc/local.ini"
[ -f "$INI" ] || { echo "no local.ini under $PREFIX/etc — is couchdb installed?" >&2; exit 1; }
echo "using $INI"

MARK="; --- obsidian-livesync (managed once by couchdb-livesync-init.sh) ---"
if grep -qF "$MARK" "$INI"; then
  echo "already configured — nothing to do"
else
  cat >> "$INI" <<EOF

$MARK
[couchdb]
single_node = true
max_document_size = 50000000

[chttpd]
require_valid_user = true
max_http_request_size = 4294967296
enable_cors = true

[chttpd_auth]
require_valid_user = true
authentication_redirect = /_utils/session.html

[httpd]
WWW-Authenticate = Basic realm="couchdb"
enable_cors = true

[cors]
origins = app://obsidian.md,capacitor://localhost,http://localhost
credentials = true
headers = accept, authorization, content-type, origin, referer
methods = GET,PUT,POST,HEAD,DELETE
max_age = 3600

[admins]
admin = $PW
EOF
  brew services restart couchdb
fi

# wait for _up, then prove auth + create the LiveSync database
for i in $(seq 1 30); do
  curl -fsS -u "admin:$PW" http://127.0.0.1:5984/_up >/dev/null 2>&1 && break
  sleep 1
  [ "$i" = 30 ] && { echo "couchdb did not come up" >&2; exit 1; }
done
curl -fsS -u "admin:$PW" -X PUT http://127.0.0.1:5984/notes >/dev/null 2>&1 || true
curl -fsS -u "admin:$PW" http://127.0.0.1:5984/notes | head -c 200; echo
echo "couchdb ready for livesync"
