#!/usr/bin/env bash
# Import album folders Soularr abandoned.
#
# Soularr needs every track of an album from a single peer's folder. One dead
# file fails the whole grab, orphaning everything already downloaded in
# downloads/. Lidarr matches those files fine, it just never gets told to look:
# DownloadedAlbumsScan is a no-op here because there is no tracked download
# client, so the import has to be driven through the ManualImport command.
#
# Only imports folders where every file matches an artist and album with no
# rejections, so a half-downloaded album is left alone to finish.
set -euo pipefail

STACK_DIR="$HOME/.local/share/music-stack"
DOWNLOADS="${1:-/Volumes/Music/downloads}"
LIDARR="http://localhost:8686"

# shellcheck disable=SC1091
KEY=$(grep -o 'LIDARR_KEY=[a-f0-9]*' "$STACK_DIR/.api-keys" | cut -d= -f2)
[ -n "$KEY" ] || { echo "no Lidarr API key in $STACK_DIR/.api-keys" >&2; exit 1; }

imported=0
for dir in "$DOWNLOADS"/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")

  payload=$(curl -sf -H "X-Api-Key: $KEY" --get --data-urlencode "folder=/downloads/$name" \
    "$LIDARR/api/v1/manualimport" \
    | jq '{name:"ManualImport", importMode:"move", replaceExistingFiles:false,
           files:[.[] | select(.artist.id and .album.id and ((.rejections|length)==0))
                      | {path, artistId:.artist.id, albumId:.album.id,
                         albumReleaseId, trackIds:[.tracks[]?.id], quality,
                         disableReleaseSwitching:false}]}') || continue

  total=$(curl -sf -H "X-Api-Key: $KEY" --get --data-urlencode "folder=/downloads/$name" \
    "$LIDARR/api/v1/manualimport" | jq 'length')
  ok=$(printf '%s' "$payload" | jq '.files|length')

  if [ "$ok" -eq 0 ] || [ "$ok" -ne "$total" ]; then
    printf '  skip   %-50s %s/%s files matched\n' "$name" "$ok" "$total"
    continue
  fi

  id=$(printf '%s' "$payload" \
    | curl -sf -X POST -H "X-Api-Key: $KEY" -H "Content-Type: application/json" \
        -d @- "$LIDARR/api/v1/command" | jq -r '.id')

  while :; do
    status=$(curl -sf -H "X-Api-Key: $KEY" "$LIDARR/api/v1/command/$id" | jq -r '.status')
    case "$status" in
      started | queued) sleep 3 ;;
      *) break ;;
    esac
  done

  printf '  %-6s %-50s %s files\n' "$status" "$name" "$ok"
  [ "$status" = "completed" ] && imported=$((imported + ok))
done

echo "imported $imported tracks"
