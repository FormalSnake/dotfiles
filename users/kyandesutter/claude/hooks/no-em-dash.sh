#!/bin/sh
# Denies any Write/Edit whose new content carries an em dash or a spaced en
# dash. The ban is stated in ~/.claude/CLAUDE.md, but a one-line rule loses to
# the thousands of em dashes sitting in the system prompt, tool descriptions,
# skills and plugin trees, so it needs enforcing rather than stating.

set -eu

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)

# Vendored upstream trees are not ours to rewrite.
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
case $path in
  */claude/plugins/*|*/.claude/plugins/*|*/skills/synced/*) exit 0 ;;
esac

content=$(printf '%s' "$input" | jq -r '
  [ .tool_input.content?,
    .tool_input.new_string?,
    .tool_input.new_source?,
    (.tool_input.edits? // [] | .[]?.new_string?)
  ] | map(select(type == "string")) | join("\n")
')

[ -n "$content" ] || exit 0

case $content in
  *"$(printf '\342\200\224')"*) bad='an em dash (U+2014)' ;;
  *"$(printf ' \342\200\223 ')"*) bad='a spaced en dash (U+2013)' ;;
  *) exit 0 ;;
esac

jq -n --arg bad "$bad" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: ("Write blocked: the content contains \($bad). ~/.claude/CLAUDE.md bans it in every file, commit, PR body and reply. Rewrite with a comma, a colon, parentheses or two sentences, then retry.")
  }
}'
