#!/bin/bash
# Obsidian free-text note inbox (macbook). Fired every 5 min by launchd
# (StartInterval, no WatchPaths). The vault holds Inbox/index.md: a freeform
# typing area above a sentinel, a watcher-owned log below. Each tick, if the
# freeform changed since last check, let headless Claude decide whether it ends
# with a "done" signal and, if so, file it into the vault (append-only). On a
# successful file the freeform is cleared and a dated copy is logged.
set -uo pipefail

VAULT="$HOME/Notes"
FILE="$VAULT/Inbox/index.md"
STATE="$VAULT/_inbox/note-watcher.state"
LOG="$VAULT/_inbox/note-watcher.log"
SENTINEL='<!-- watcher log below (do not edit) -->'
[ -d "$VAULT/_inbox" ] || exit 0

# mkdir-based lock (no flock on macOS); a queued tick retries later.
LOCK="$VAULT/_inbox/.note-watcher.lock"
if ! mkdir "$LOCK" 2>/dev/null; then exit 0; fi
trap 'rmdir "$LOCK"' EXIT

# Seed the skeleton on first run so the file appears (and syncs) with no manual step.
if [ ! -f "$FILE" ]; then
  mkdir -p "$VAULT/Inbox"
  printf '# Inbox\n\n%s\n## Log\n' "$SENTINEL" > "$FILE"
  exit 0
fi

# Freeform = everything above the sentinel, minus the leading "# Inbox" heading.
freeform=$(awk -v s="$SENTINEL" 'index($0,s){exit} {print}' "$FILE")
body=$(printf '%s\n' "$freeform" | awk 'NR==1 && $0 ~ /^# Inbox[[:space:]]*$/ {next} {print}')

# Nothing to file → mark empty and stop (never invokes Claude).
if [ -z "$(printf '%s' "$body" | tr -d '[:space:]')" ]; then
  printf '' > "$STATE"; exit 0
fi

# Change gate: skip if the freeform is unchanged since the last check.
hash=$(printf '%s' "$body" | shasum -a 256 | cut -d' ' -f1)
[ "$hash" = "$(cat "$STATE" 2>/dev/null || true)" ] && exit 0

# Settle check: don't read a file that's mid-sync/mid-type; retry next tick
# (state left untouched so the change is still seen).
s1=$(stat -f%z "$FILE"); sleep 2; s2=$(stat -f%z "$FILE")
[ "$s1" = "$s2" ] || exit 0

prompt="You are the note-inbox assistant for this Obsidian vault (the current directory).
The owner types raw free-text captures into Inbox/index.md. Here is the current freeform text:
---
$body
---

1. First decide whether this text ends with a natural 'I'm done / file this' signal (phrased
   however the owner likes — 'done', 'that's it', 'dat was het', 'file this', etc.). If it does
   NOT, output exactly 'PENDING' and change no files — they are still drafting.
2. Otherwise read Home.md, then search existing notes (Projects/, Startup/, Meetings/, Ideas/,
   Inbox/) to resolve project names and the owner's shorthand.
3. File it: APPEND to the best-matching existing note under a new heading '## Note $(date +%Y-%m-%d)',
   or create a new note in the best-fitting folder — create the project note (e.g. Projects/<Name>.md)
   when it's a new project. Group mixed content sensibly: bug/error reports under a bugs section,
   feature ideas under features. If genuinely unsure, create a new topic-named note in Inbox/.
4. NEVER touch Inbox/index.md — that is the inbox file itself, not a filing destination.
5. NEVER delete, rewrite, or reorder existing content — append only. No YAML frontmatter. Keep the
   markdown plain and calm.
6. Your very last output line MUST be exactly 'FILED: <vault-relative note path>' on success, or
   'PENDING' if there was no done signal."

out="$VAULT/_inbox/.note-agent-out.$$"
(cd "$VAULT" && claude -p "$prompt" \
    --model sonnet --max-turns 30 \
    --allowedTools "Read,Glob,Grep,Write,Edit") > "$out" 2>&1
rc=$?
cat "$out" >> "$LOG"

if [ $rc -eq 0 ] && grep -q '^FILED:' "$out"; then
  dest=$(grep '^FILED:' "$out" | tail -1 | sed 's/^FILED:[[:space:]]*//')
  oldlog=$(awk 'f{print} /^## Log/{f=1}' "$FILE")
  {
    printf '# Inbox\n\n%s\n## Log\n' "$SENTINEL"
    printf '### %s → %s\n' "$(date '+%Y-%m-%d %H:%M')" "$dest"
    printf '%s\n\n' "$body"
    printf '%s' "$oldlog"
  } > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
  printf '' > "$STATE"
  echo "$(date -Iseconds) OK -> $dest" >> "$LOG"
else
  # PENDING or failure: leave the freeform alone, but record the hash so we
  # don't re-examine it until the owner edits again.
  echo "$hash" > "$STATE"
  if grep -q '^PENDING$' "$out"; then
    echo "$(date -Iseconds) PENDING (no done signal)" >> "$LOG"
  else
    echo "$(date -Iseconds) FAILED (agent rc=$rc)" >> "$LOG"
  fi
fi
rm -f "$out"
