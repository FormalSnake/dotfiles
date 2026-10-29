#!/bin/bash
# fspec.couchdb. Homebrew keeps couchdb's local.ini inside the keg, so an upgrade drops the
# LiveSync settings and the admin. They live in var/couchdb instead, which upgrades leave alone.
# CouchDB hashes the plain admin password in place on its first start, so the file is written
# once and then belongs to CouchDB.
set -euo pipefail
ROOT=/opt/homebrew/opt/couchdb
INI=/opt/homebrew/var/couchdb/local.ini
PW_FILE=/var/run/fspec/secrets/couchdb-admin
if [ ! -f "$INI" ]; then
  [ -r "$PW_FILE" ] || { echo "missing $PW_FILE" >&2; exit 1; }
  umask 077
  cat >"$INI" <<INI
[couchdb]
single_node = true
max_document_size = 50000000

[chttpd]
bind_address = 127.0.0.1
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
admin = $(cat "$PW_FILE")
INI
fi
export COUCHDB_INI_FILES="$ROOT/etc/default.ini $ROOT/etc/default.d $INI"
exec "$ROOT/bin/couchdb"
