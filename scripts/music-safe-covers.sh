#!/usr/bin/env bash
# Replace an artist's album art with typographic covers over a blurred wash of
# the original.
#
# Writes cover.jpg, never folder.jpg: cover.* outranks folder.* in Navidrome's
# CoverArtPriority and Lidarr's Kodi metadata consumer only ever writes
# folder.jpg, so an artist refresh cannot undo this. Reverting is a matter of
# deleting the cover.jpg files.
#
# Navidrome serves art from the album folder, so --embed is only needed for
# clients that read tags off downloaded files.
set -euo pipefail

LIBRARY="${MUSIC_LIBRARY:-/Volumes/Music/library}"
FONT_TITLE="$HOME/Library/Fonts/SpotifyMix-Black.otf"
FONT_META="$HOME/Library/Fonts/SpotifyMix-Medium.otf"

SIZE=1200
MARGIN=90
TITLE_BOX=$((SIZE - MARGIN * 2))
TITLE_MAX_H=560

embed=false
[ "${1:-}" = "--embed" ] && { embed=true; shift; }
artist="${1:?usage: music-safe-covers.sh [--embed] <artist folder>}"

artist_dir="$LIBRARY/$artist"
[ -d "$artist_dir" ] || { echo "no such artist folder: $artist_dir" >&2; exit 1; }

for font in "$FONT_TITLE" "$FONT_META"; do
  [ -f "$font" ] || { echo "missing font: $font" >&2; exit 1; }
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for dir in "$artist_dir"/*/; do
  [ -d "$dir" ] || continue
  album=$(basename "$dir")
  track=$(find "$dir" -maxdepth 1 -name '*.flac' -print -quit)
  [ -n "$track" ] || continue

  # The blur only needs a few average colours, so any of the artwork the album
  # already has will do. cover.jpg is deliberately not a candidate and embedded
  # art is the last resort: both are outputs of this script once it has run, and
  # blurring its own output stacks a second wash over baked-in text on every
  # re-run. Everything ahead of them is written by Lidarr and stays pristine.
  src=""
  for candidate in "$dir/folder.jpg" "$dir/front.jpg" "$artist_dir/artist.jpg"; do
    [ -f "$candidate" ] && { src="$candidate"; break; }
  done
  if [ -z "$src" ]; then
    if ffmpeg -v error -y -i "$track" -an -c:v copy "$work/embedded.jpg" 2>/dev/null \
      && [ -s "$work/embedded.jpg" ]; then
      src="$work/embedded.jpg"
    else
      printf '  skip   %-50s no source image\n' "$album"
      continue
    fi
  fi

  title=$(ffprobe -v error -show_entries format_tags=album -of default=nk=1:nw=1 "$track")
  [ -n "$title" ] || title="${album% (*}"
  year=$(expr "$album" : '.*(\([0-9]\{4\}\))$' || true)

  # 4x4 then back up averages the artwork down to a handful of colour fields;
  # the blur removes the seams. Blurring at 400px and enlarging afterwards
  # keeps the same wash for a fraction of the cost of a sigma-60 kernel at
  # full size.
  magick "$src" -resize 4x4! -resize 400x400! -blur 0x20 \
    -resize "${SIZE}x${SIZE}!" "$work/bg.png"

  # Palettes range from near-black to washed-out pastel across one artist, so
  # the ink has to follow the wash, and the wash is pushed away from it, or
  # half the covers come out unreadable.
  lum=$(magick "$work/bg.png" -colorspace Gray -format '%[fx:mean]' info:)
  if awk -v l="$lum" 'BEGIN { exit !(l > 0.5) }'; then
    ink='#12100Ee6'; ink_meta='#12100Ea6'; wash='14x0'
  else
    ink='#FFFFFFf2'; ink_meta='#FFFFFFb3'; wash='-14x0'
  fi

  # caption: wraps at the box width but grows unbounded in height, so step the
  # size down until a long title fits rather than letting it run off the cover.
  for pointsize in 132 120 108 96 84 72 64 56 48; do
    h=$(magick -background none -font "$FONT_TITLE" -pointsize "$pointsize" \
      -size "${TITLE_BOX}x" caption:"$title" -format '%[fx:h]' info:)
    [ "$h" -le "$TITLE_MAX_H" ] && break
  done

  # The title is rendered in its own invocation because -size is global in
  # ImageMagick and survives the parentheses: sharing a command line with the
  # meta text makes label: auto-fit both lines to the title box.
  magick -background none -fill "$ink" -font "$FONT_TITLE" -pointsize "$pointsize" \
    -size "${TITLE_BOX}x" caption:"$title" "$work/title.png"

  magick "$work/bg.png" -brightness-contrast "$wash" \
    "$work/title.png" -gravity northwest -geometry "+${MARGIN}+${MARGIN}" -composite \
    -font "$FONT_META" -pointsize 34 -fill "$ink_meta" \
    -kerning 8 -gravity southwest -annotate "+${MARGIN}+${MARGIN}" "ARTEMAS" \
    -kerning 0 -gravity southeast -annotate "+${MARGIN}+${MARGIN}" "$year" \
    -quality 92 "$dir/cover.jpg"

  if $embed; then
    for f in "$dir"/*.flac; do
      ffmpeg -v error -y -i "$f" -i "$dir/cover.jpg" -map 0:a -map 1 -c copy \
        -disposition:v attached_pic \
        -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" \
        "$work/out.flac"
      mv "$work/out.flac" "$f"
    done
  fi

  printf '  wrote  %-50s %spt\n' "$album" "$pointsize"
done
