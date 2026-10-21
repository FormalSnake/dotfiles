#!/bin/sh
# Denies a Bash call that would write AI attribution or a forged identity into git
# history: a Co-Authored-By / Claude-Session trailer, a "Generated with Claude Code"
# footer, --author=, GIT_AUTHOR_* / GIT_COMMITTER_*, or a user.name / user.email write.
# ~/.claude/CLAUDE.md bans all of these, but the harness injects the trailers into
# every session's system prompt, so the rule needs teeth.

set -eu

command -v jq >/dev/null 2>&1 || exit 0

cmd=$(cat | jq -r '.tool_input.command // ""')
[ -n "$cmd" ] || exit 0

deny() {
  jq -n --arg why "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("Blocked: " + $why + ". ~/.claude/CLAUDE.md forbids any AI attribution trailer and any git identity override. Drop it and retry with the plain message.")
    }
  }'
  exit 0
}

# Identity overrides are banned on every git command, reads excepted.
if printf '%s' "$cmd" | grep -Eq -e '--author=' -e '(^|[^A-Za-z_])GIT_(AUTHOR|COMMITTER)_(NAME|EMAIL)=' -e 'git[[:space:]]+-c[[:space:]]+user\.(name|email)='; then
  deny "the command sets the git author or committer identity"
fi
if printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+config([[:space:]]+--(global|local|system|worktree|file[[:space:]]+[^[:space:]]+))*[[:space:]]+user\.(name|email)[[:space:]]+[^[:space:]]'; then
  deny "the command writes git user.name or user.email"
fi

# Attribution only matters where it lands in history: commits, merges, tags, PRs.
printf '%s' "$cmd" | grep -Eq '(^|[^A-Za-z-])(git[[:space:]]+(commit|merge|tag|rebase|am|notes|interpret-trailers)|gh[[:space:]]+(pr|api|release))([[:space:]]|$)' || exit 0

if printf '%s' "$cmd" | grep -Eiq -e 'co-authored-by' -e 'claude-session' -e 'noreply@anthropic\.com' -e 'claude\.ai/code' -e 'generated with.*claude'; then
  deny "the commit or PR text carries an AI attribution (Co-Authored-By / Claude-Session / Generated with Claude Code)"
fi

exit 0
