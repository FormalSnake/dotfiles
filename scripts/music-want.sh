#!/usr/bin/env bash
# Ask Lidarr for one album instead of an artist's whole MusicBrainz catalogue.
#
# Adding an artist in the web UI used to monitor every release MusicBrainz
# lists for them, which is how one liked song turned into a 13-album download.
# The root folder now defaults to monitoring nothing, so an add is inert until
# something turns an album on. This is that something: it adds the artist if
# they are new, leaves the rest of the catalogue alone, and monitors the one
# album you asked for. Soularr picks it up on its next 300s poll.
#
# Usage:
#   music-want.sh "Artist" "Album"
#   music-want.sh --track "Artist" "Song title"     # the album carrying it
set -euo pipefail

STACK_DIR="$HOME/.local/share/music-stack"
LIDARR="http://localhost:8686/api/v1"

by_track=false
[ "${1:-}" = "--track" ] && { by_track=true; shift; }
artist=${1:-}
target=${2:-}
[ -n "$artist" ] && [ -n "$target" ] || {
  echo "usage: $0 [--track] <artist> <album | song title>" >&2; exit 1; }

KEY=$(grep -o 'LIDARR_KEY=[a-f0-9]*' "$STACK_DIR/.api-keys" | cut -d= -f2)
[ -n "$KEY" ] || { echo "no Lidarr API key in $STACK_DIR/.api-keys" >&2; exit 1; }

get() { curl -sf -H "X-Api-Key: $KEY" "$LIDARR/$1"; }
send() {
  curl -sf -X "$1" -H "X-Api-Key: $KEY" -H "Content-Type: application/json" \
    -d @- "$LIDARR/$2"
}

# /album/monitor answers 202 and does the work behind a command queue, so two
# calls issued back to back land in either order. Every one of them is followed
# by a poll on the state it was meant to produce.
settle() {
  for _ in $(seq 20); do
    get "album?artistId=$1" | jq -e "$2" >/dev/null && return 0
    sleep 1
  done
  echo "lidarr never settled on: $2" >&2
  return 1
}

id=$(get artist | jq -r --arg n "$artist" '(map(select(.artistName == $n))[0].id) // empty')

if [ -z "$id" ]; then
  # monitor "none" does not mean what it says: it clears the artist row and
  # leaves every album `monitored: true`, so the discography would light up the
  # moment the artist is re-monitored below. The albums are cleared by hand
  # after the refresh, which is what actually keeps an add inert.
  found=$(get "artist/lookup?term=$(jq -rn --arg t "$artist" '$t|@uri')" \
    | jq -c --arg n "$artist" '(map(select(.artistName == $n))[0] // .[0]) // empty')
  [ -n "$found" ] || { echo "no MusicBrainz artist matching $artist" >&2; exit 1; }
  root=$(get rootfolder | jq -c '.[0]')
  id=$(printf '%s' "$found" \
    | jq -c --argjson r "$root" '
        .qualityProfileId = $r.defaultQualityProfileId
        | .metadataProfileId = $r.defaultMetadataProfileId
        | .monitored = true
        | .rootFolderPath = $r.path
        | .addOptions = {monitor: "none", searchForMissingAlbums: false}' \
    | send POST artist | jq -r .id)
  echo "added $artist as artist $id, nothing monitored"
  send POST command <<<"{\"name\":\"RefreshArtist\",\"artistId\":$id}" >/dev/null
  # Missing state is computed by the refresh, not by the add, so an album
  # monitored before it finishes never becomes wanted.
  for _ in $(seq 30); do
    [ "$(get "album?artistId=$id" | jq 'length')" -gt 0 ] && break
    sleep 2
  done
  all=$(get "album?artistId=$id" | jq -c '[.[].id]')
  if [ "$all" != "[]" ]; then
    send PUT album/monitor <<<"{\"albumIds\":$all,\"monitored\":false}" >/dev/null
    settle "$id" 'all(.monitored | not)'
  fi
fi

albums=$(get "album?artistId=$id")
if $by_track; then
  album=""
  while read -r aid; do
    if get "track?albumId=$aid" \
        | jq -e --arg t "$target" 'map(select(.title | ascii_downcase == ($t|ascii_downcase))) | length > 0' >/dev/null; then
      album=$aid
      break
    fi
  done < <(printf '%s' "$albums" | jq -r '.[].id')
  [ -n "$album" ] || {
    echo "no album by $artist carrying \"$target\". A standalone single needs the" >&2
    echo "Singles and Albums metadata profile: add the artist to kyan.music.singlesArtists." >&2
    exit 1; }
else
  album=$(printf '%s' "$albums" \
    | jq -r --arg t "$target" '(map(select(.title | ascii_downcase == ($t|ascii_downcase)))[0].id) // empty')
  [ -n "$album" ] || { echo "$artist has no album \"$target\" in Lidarr" >&2; exit 1; }
fi

title=$(printf '%s' "$albums" | jq -r --arg a "$album" 'map(select(.id == ($a|tonumber)))[0].title')

send PUT album/monitor <<<"{\"albumIds\":[$album],\"monitored\":true}" >/dev/null
settle "$id" "any(.id == $album and .monitored)"

# Last, and only now: clearing every album unmonitors the artist row as a side
# effect, and an unmonitored artist has no missing albums however the album
# flags read.
get "artist/$id" | jq '.monitored = true' | send PUT "artist/$id" >/dev/null
echo "wanted: $artist - $title (album $album)"
