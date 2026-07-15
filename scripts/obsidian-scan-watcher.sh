#!/bin/bash
# Obsidian notebook-scan pipeline (macbook). Fired by launchd WatchPaths on
# ~/Notes/_inbox/scans (+ a slow StartInterval safety net). For each settled
# image: archive to Attachments/scans/<year>/, then let headless Claude
# transcribe + file it with the vault as context. Append-only by prompt.
set -uo pipefail

VAULT="$HOME/Notes"
SCANS="$VAULT/_inbox/scans"
LOG="$SCANS/watcher.log"
[ -d "$SCANS" ] || exit 0

# mkdir-based lock (no flock on macOS); a queued launchd fire retries later.
LOCK="$SCANS/.watcher.lock"
if ! mkdir "$LOCK" 2>/dev/null; then exit 0; fi
trap 'rmdir "$LOCK"' EXIT

shopt -s nullglob nocaseglob
for img in "$SCANS"/*.{jpg,jpeg,png,webp,heic}; do
  [ -f "$img" ] || continue

  # settle check: skip files still being synced in; next fire picks them up
  s1=$(stat -f%z "$img"); sleep 2; s2=$(stat -f%z "$img")
  [ "$s1" = "$s2" ] || continue

  base=$(basename "$img")

  # HEIC → JPEG (Claude's Read tool can't open HEIC); sips ships with macOS
  case "$img" in
    *.heic|*.HEIC)
      jpg="${img%.*}.jpg"
      if sips -s format jpeg "$img" --out "$jpg" >/dev/null 2>&1; then
        rm -f "$img"; img="$jpg"; base=$(basename "$img")
      else
        mkdir -p "$SCANS/failed"; mv "$img" "$SCANS/failed/$base"
        echo "$(date -Iseconds) FAILED(heic-convert) $base" >> "$LOG"; continue
      fi ;;
  esac

  year=$(date +%Y)
  mkdir -p "$VAULT/Attachments/scans/$year" "$SCANS/failed"
  stamped="$(date +%Y%m%d-%H%M%S)-$base"
  rel="Attachments/scans/$year/$stamped"
  mv "$img" "$VAULT/$rel"

  prompt="You are the notebook-scan assistant for this Obsidian vault (the current directory).
A photo of handwritten notebook page(s) is at: $rel

1. Read the image and transcribe the handwriting into clean markdown — keep the
   author's headings/lists/emphasis; describe sketches or diagrams briefly in
   [square brackets]. Don't invent content you can't read; mark it '(illegible)'.
2. Read Home.md, then search existing notes (Projects/, Startup/, Meetings/,
   Ideas/, Inbox/) to resolve project names and the author's personal shorthand —
   use existing notes to interpret ambiguous terms.
3. File it: if the content clearly belongs to an existing note, APPEND to that
   note under a new heading '## Scanned $(date +%Y-%m-%d)'. Otherwise create a
   new note in the best-fitting folder (Meetings/ notes are named
   'YYYY-MM-DD topic.md'). If genuinely unsure, create it in Inbox/.
4. End the appended/new section with an embed of the original page: ![[$rel]]
5. NEVER delete, rewrite, or reorder existing content — append only. No YAML
   frontmatter. Keep the markdown plain and calm."

  if (cd "$VAULT" && claude -p "$prompt" \
        --model sonnet --max-turns 30 \
        --allowedTools "Read,Glob,Grep,Write,Edit") >> "$LOG" 2>&1; then
    echo "$(date -Iseconds) OK $base -> $rel" >> "$LOG"
  else
    mv "$VAULT/$rel" "$SCANS/failed/$base"
    echo "$(date -Iseconds) FAILED(agent) $base" >> "$LOG"
  fi
done
