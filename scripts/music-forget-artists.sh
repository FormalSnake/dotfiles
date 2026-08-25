#!/usr/bin/env bash
# Remove artists from Lidarr together with everything they left on the SD card.
#
# Lidarr's own delete only clears the artist folder under library/. Soularr's
# downloads (shared back to Soulseek) and the failed_imports parking lot keep
# their copies, so the space never comes back on its own. Folder names there
# come from the peer's share, but Soularr and the rescue script both prefix
# them "<artist> - ", which is what the prune matches.
#
# Usage: music-forget-artists.sh <lidarr artist id | from-to> ...
set -euo pipefail

STACK_DIR="$HOME/.local/share/music-stack"
DOWNLOADS="${DOWNLOADS:-/Volumes/Music/downloads}"
LIDARR="http://localhost:8686"
SLSKD="http://localhost:5030"

KEY=$(grep -o 'LIDARR_KEY=[a-f0-9]*' "$STACK_DIR/.api-keys" | cut -d= -f2)
SLSKD_KEY=$(grep -o 'SLSKD_KEY=[a-f0-9]*' "$STACK_DIR/.api-keys" | cut -d= -f2)
[ -n "$KEY" ] || { echo "no Lidarr API key in $STACK_DIR/.api-keys" >&2; exit 1; }

ids=()
for arg in "$@"; do
  case "$arg" in
    *-*) ids+=($(seq "${arg%-*}" "${arg#*-}")) ;;
    *) ids+=("$arg") ;;
  esac
done
[ "${#ids[@]}" -gt 0 ] || { echo "usage: $0 <id | from-to> ..." >&2; exit 1; }

for id in "${ids[@]}"; do
  name=$(curl -sf -H "X-Api-Key: $KEY" "$LIDARR/api/v1/artist/$id" | jq -r .artistName) || {
    printf '  skip   %s not in Lidarr\n' "$id"; continue; }
  curl -sf -o /dev/null -X DELETE -H "X-Api-Key: $KEY" \
    "$LIDARR/api/v1/artist/$id?deleteFiles=true&addImportListExclusion=false"
  printf '  gone   %-40s lidarr\n' "$name"

  for base in "$DOWNLOADS" "$DOWNLOADS/failed_imports"; do
    while IFS= read -r dir; do
      rm -rf -- "$dir"
      printf '  pruned %s\n' "${dir#"$DOWNLOADS"/}"
    done < <(find "$base" -mindepth 1 -maxdepth 1 -type d -iname "$name - *" 2>/dev/null)
  done
done

# slskd advertises downloads/ to peers and only rescans on demand.
[ -n "$SLSKD_KEY" ] && curl -sf -o /dev/null -X PUT -H "X-API-Key: $SLSKD_KEY" "$SLSKD/api/v0/shares" || true
