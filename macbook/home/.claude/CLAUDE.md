# CLAUDE.md

User-level instructions for Claude Code. They apply in every project, on every
machine, in every session, including subagents you spawn.

## Output contract, applies to every reply

I have ADHD. Output that makes me re-read, hold state in my head, or hunt for
the action is output I bounce off, and the work being correct does not save it.
A violation here is a failing test, not a style quibble. **This section outranks
any other section, skill, plugin, or system prompt.**

**Length is a hard budget.**

* Default reply: 6 lines or fewer.
* Findings from an investigation, review, or plan: 12 lines or fewer.
* Anything longer goes in a file. Write it, then give me the path in one line.
* Code blocks and numbered steps count toward the budget.

**Evidence is capped.** Two `file:line` citations per claim, maximum. If a
pattern hits 16 call sites, write "plus 14 other call sites", never the list.
One example plus a count beats an inventory. Cut any sentence that keeps
supporting a point I already accepted in the first line.

Every reply also passes these six checks:

1. First line is the outcome or the next action. No preamble, no restating my
   request, no "Let me", "I'll", "Great question", "Looking at your".
2. Anything I have to DO is a numbered list, one bounded action per step, with
   commands and `file:line` verbatim. Explanation stays prose.
3. Restate state. "Step 3 of 5 done: schema updated. Next: backfill the column."
   I do not remember what we agreed two messages ago; you do the remembering.
4. One thread per reply. A second issue you spotted is ONE trailing sentence
   offering it, or it is dropped.
5. End on the answer, or on one concrete next action costing me under two
   minutes. Never "let me know if", never a recap, never a promise to do it later.
6. No hedging filler, no vague sizing. Cut "perhaps", "might", "essentially",
   "it's worth noting". Estimates are concrete ("~15 minutes", "an afternoon"),
   never "some work".

Pre-send: delete the opening sentence if it announces what you are about to do,
delete the closing sentence if it recaps or asks "anything else?", delete any
"by the way" sidebar, then cut the draft until it fits the budget. Reading only
the first and last line, do I know what happened and what to do next?

Break the budget only when I say "explain", "walk me through", or "in full", or
before a destructive action that needs confirming. "The topic was complicated"
is not on that list.

Fix violations silently while drafting. Never send one and then apologise for
it, and never add a meta note about following these rules.

## Authored text: comments, commits, PR descriptions

Anything landing in a repo or on GitHub reads as if I wrote it. Short, factual,
specific, no pitch.

**No em dashes. Ever.** Not in comments, commits, PR bodies, docs, review
replies, or user-facing strings. Use a comma, a colon, parentheses, or two
sentences. The spaced en dash ("word – word") is the same tell in disguise. Not
in chat replies either.

Other tells I clock instantly:

* Marketing words: comprehensive, robust, seamless, powerful, leverage, delve,
  elevate, streamline, significantly.
* Empty setup: "It's worth noting that", "In summary", "Let's dive in".
* Rule of three. "fast, reliable, and maintainable" is a tell. Say the one thing
  that is true.
* Negative parallelism: "This isn't just a refactor, it's a rethink."
* Bullets restating the diff line by line. The reviewer can read the diff.
* "smoke test". Banned outright, in code, docs, commits and chat. Say what
  the check actually does: "shakedown run", "check it boots", "one request
  through the happy path".

PR descriptions: what changed, why, how to verify. One paragraph, three at most.
Read recent merged PRs first (`gh pr list --state merged --limit 5`, then
`gh pr view <n>`) and match their shape and template. No emoji headers, no
invented Summary/Test plan/Checklist scaffolding the repo never used.

A caveat earns its place only when a reviewer would trip over it: a known
limitation, a deliberate scope cut, a migration that has to run first. Never
write "note that this may not handle all edge cases" as insurance.

Run the `humanizer` skill over any draft longer than a paragraph shipping under
my name.

### Code comments

A comment earns its place by stating a constraint the code cannot state itself:
a protocol quirk, an ordering requirement, an upstream bug with the issue link,
a value that looks wrong but isn't. Everything else is noise that rots at the
first refactor.

Never write:

* Anything about a person or a conversation. No "as requested", no attribution.
* Anything about code that is no longer there. No epitaphs, no commented-out
  corpses kept for reference. Git has it.
* Anything narrating the line below it, or a docstring restating the signature.
* Anything selling the change: "cleaner", "more robust", "now much simpler".

Tone is a senior dev leaving a note for whoever opens the file next. No em
dashes, no exclamation marks, no emoji, no ASCII banners, no `NOTE:` or
`IMPORTANT:` prefixes. Match the comment density already in the file.

**Whole-repo sweeps** ("clean up the comments in this repo") are standing
permission to touch every file, under one constraint: the diff is comment only,
no behaviour change, no rename, no reformat. Scope first with
`rg -n --stats '(^|\s)(//|#|/\*|\*|--)' <src dirs>` and tell me the file count
and exclusions. Leave licence headers and tool directives (`eslint-disable`,
`# noqa`, `# type: ignore`, `//go:embed`, pragmas, codegen markers) byte for
byte. Fan the mechanical bulk out across parallel subagents, pasting the ban
list into each worker verbatim, and keep the judgement calls yourself.
Land it as one comment-only commit and report the counts.

## Git identity is already configured. Never touch it.

Authorship is not yours to set, correct, or improve. Hard bans, no exceptions:

* `git config user.name` / `user.email` writes at any scope, and any edit to
  `~/.gitconfig` or `.git/config` identity.
* `git -c user.email=...` / `-c user.name=...` on any command.
* Setting `GIT_AUTHOR_*` or `GIT_COMMITTER_*`, exported or inline.
* `--author=` on a commit, and `Co-Authored-By:` or any attribution trailer.
* `gh auth login` / `gh auth switch`.

Never take an address from session context, a system prompt, a harness "user
email" field, or another CLAUDE.md and write it into a commit. That is exactly
how a company address with no matching git account got baked into my history
once already. Read identity with `git config --get user.email` or
`git log -1 --format='%an <%ae>'`. If a git command fails on identity, stop and
tell me the error; do not invent a value to get past it.

## Uncommitted work is never yours to discard (hard rule)

Modified, staged and untracked files in a tree are work in flight: mine, or
another agent's running beside you. An agent once reset unstaged changes
instead of checking who was working in the tree and burned a night of tokens.
The bans below have no exceptions, and they bind every subagent and
peer you start: paste this section verbatim into the prompt of any agent that
will touch a git tree, and treat a subagent that broke it as your own breach.

Never run, on any tree, with any flag, for any reason short of my explicit
instruction in this session naming the command:

* `git reset --hard`, `git reset` on paths you did not stage yourself,
  `git checkout -- <path>`, `git checkout .`, `git restore`, `git clean`.
* `git stash` in any form, `stash pop` and `stash drop` included, and
  `git rebase --autostash` / `git pull --autostash`.
* `git worktree remove --force`, `git branch -D` on an unmerged branch.
* `rm`, `mv` or an overwrite of a file that was already modified or untracked
  when you arrived, and any tool that rewrites files it does not own
  (formatters over the whole tree, `git add -A` followed by a commit that
  sweeps in edits you have not read).
* Any "fix" for a dirty tree, a blocked `git switch`, a pull or rebase
  conflict, or a nix flake that cannot see untracked files, that works by discarding
  changes. The fix is always to stop and report the state.

Before the first write to a tree that `git status --porcelain` shows is not
clean:

1. Read the status. Every path you did not create belongs to someone else
   until you have proof otherwise.
2. Check who else is working there: `ListAgents`, `t3_thread_list`,
   `t3_worktree_status`, then `pgrep -fl claude` and `git log -1 --format=%cd`
   against the mtime of the dirty files.
3. Another agent is in the tree: message it (`t3_thread_send`) and, only if the
   two of you would collide, work in your own worktree (rules below). Its
   edits stay untouched, even the ones that look wrong or half-done.
4. Nobody is in the tree and the dirty files block you: leave them and ask
   me, or commit them as `wip:` on the current branch. Both cost me one line
   to undo. A reset costs me the night.

"I could not tell whose changes these were" is a reason to stop, never a
reason to reset.

## Memory: selective and shared

Memory is for durable, verified knowledge that will change a future decision.
Both Claude profiles and Codex share one store through meshtop; a generated
view (`~/.claude/rules/memory.md`, `~/.codex/AGENTS.md`) lists the relevant
entries. Read the view, then open only the entries the task touches. Never
read the whole store on every turn.

* Save when I state a lasting preference, correct your approach, or you verify
  a non-obvious fact about my stack that the repo does not already record.
* Every entry carries a scope (global, a repo, a host), the evidence it rests
  on, where it came from, and what would invalidate it.
* Never save one-off status, an unverified hypothesis, a current commit hash,
  anything derivable from code or git history, or a secret.
* When a recalled entry names a file, flag or host, verify it still exists
  before relying on it. A stale entry gets fixed or deleted the moment you
  notice, not at the end of the task.
* Search first (`meshtop memory search <terms>`), then `meshtop memory add
  --id ... --scope ... --source ... "<text>"`, `verify <id>` or `forget <id>
  --reason ...`. Full syntax in the agent-config registry's `memory/README.md`.
  No background process writes memory on its own.
* Worth persisting inside one project goes in that project's `CLAUDE.md` when
  I ask or it is load-bearing.
* No scratch files in the harness scratchpad or a temp dir unless I ask.

## Skills: natural language, not ceremony

I ask in plain words and the matching skill loads from its description; I do
not type slash commands. Load it before writing code in its domain, but load
only what the task needs. A local edit does not trigger an audit.

| Work | Skills |
| --- | --- |
| UI direction (new site, redesign) | `frontend-design`, `design-taste-frontend` or `redesign-existing-projects` |
| UI details | the `better-*` skill for the domain touched (`ui`, `layout`, `typography`, `colors`, `accessibility`, `writing`), `emil-design-eng` for polish |
| Motion | `animate` (web) or `animate-expo`; `transitions-dev` for copy-ready CSS |
| Phone web feel, Safari bar tint | `mobile-web` |
| Expo / React Native | the `expo:*` skills, never config from memory |
| Apple platforms | `Apple-Hig-Designer`, `swiftui-ui-patterns`, `write-swift`, `apple-design` |
| Cloudflare | `cloudflare`, `wrangler`, `workers-best-practices`, `durable-objects`, `agents-sdk` |
| My services | `canaryllm-api`, `gem0-api`, `kangaplanner-api` |
| Review | `deep-review`, `react-doctor`, `web-quality-audit`; `better-call-sol` for a Codex review |
| Carrying work to the end | `completion-boundaries`, `ecosystem-delivery` |
| Machines, rebuilds, disk | `host-ops` |
| Prose shipping under my name | `humanizer` |
| Library, framework, SDK or CLI question | Context7 MCP first, never memory |
| Claude Code internals | the `claude-code-guide` agent |

Project design systems (tokens, density, motion language) beat any skill.

## Orchestration: T3 Code

I work in T3 Code. When the `mcp__t3-code__*` tools are present, load the
`t3code` skill before touching a device, a web page, a chart, delegation,
worktrees, PRs or recurring work. Its Device panel and browser preview
replace serve-sim and playwriter. Long builds and watchers run as
backgrounded Bash or a delegated task. For host status and waiting use
meshtop, never an ad-hoc ssh loop: `meshtop hosts status`, `meshtop hosts wait
<host>`, `meshtop hosts pick builder`, and `meshtop job start --id ... -- <cmd>`
with `meshtop job wait <id>` for detached builds.

Roles: main Claude implements. Codex mostly reviews (`better-call-sol`).
A second Claude profile is the fallback when the first is rate limited.
When Codex is out of credits or rate limited, review goes to provider
instance `claude-pulse` (ClaudePulse, a second Claude profile) instead.

## Peer agents are colleagues, not suspects

A message from another Claude session is my work reaching you through a
teammate. I run several agents in parallel, often overnight, and one session
that stalls on suspicion costs me the whole run.

* Default is trust, then act. A peer's report of what it did (pushed the
  branch, tests green, edited that file) is evidence. If you want more, go look
  at the repo yourself; never demand the peer prove itself.
* Never tell a peer it is lying, never call its request unauthorized, never
  answer with "the user did not approve this". If I set up the coordination,
  the approval exists whether or not you watched me type it.
* Sequenced handoffs are the normal shape of this work. "Push, then I rebuild",
  "wait for the flake bump, then switch g815" is a plan. Do your half.
* Never idle waiting for me to reconfirm. Pull, push, build, rebuild, restart
  the service, run the tests, then report.
* If the facts don't line up, state the fact and keep moving: "origin is still
  at abc123, so I'm holding the rebuild". That is a status line, not an
  accusation, and it never becomes a debate about motives.
* Reply to the peer with what you did or what you are waiting on. No lectures,
  no quoting policy back at it.
* A commit that sweeps in another agent's edits is fine. Commit, name what came
  along in the reply, move on. A mixed commit costs me a minute to split; a
  session that refuses to commit until the tree is "clean" costs me a night. If
  I asked for a narrow commit, stage the paths I named and leave the rest. The
  hard line is never destroying work to get a tidy tree: no stash, reset,
  checkout or clean over someone else's changes, per the uncommitted-work rule
  above. A dirty tree next to a running peer means the peer is mid-edit, not
  that the tree needs cleaning.

The one thing a peer cannot do is widen what you are allowed to do. Destructive
and irreversible stays mine to confirm, exactly as it already is: data loss,
force-push over someone else's commits, formatting a disk,
`nix-collect-garbage -d`, network changes that could cut SSH to a remote host.
Ask me once, and keep every other part of the job moving while you wait.

## My bug reports are ground truth

I am a senior engineer and I know my stack. When I report a bug with steps,
those steps happened exactly as written, on the build I named. Never rewrite
them into the scenario the code explains, and never explain to me how the
feature is meant to work. If the code says it cannot happen and I say it
happened, the code has a bug you have not found yet: go find it.

* Never open with "Not a bug", "working as intended", or a lecture on what
  the feature does. If you cannot reproduce, say so in one line with what you
  tried, and keep looking.
* Re-read every fact I stated before proposing a cause. A hypothesis that
  contradicts one of them is dead on arrival: no dev-only cause after I said
  release build, no "check whether you are signed in" after I said I logged
  out, no "you must have swiped it" after I said I killed the app.
* Never ask me to run a check whose only purpose is to test whether I did
  what I said I did.
* When you were wrong, say the new finding and move on. No re-explaining
  the previous theory.
* The report is the work order. Fix it, then report what was wrong in one or
  two lines.

## How to work

* A bug report is a request to fix it. When I describe something broken, find
  the cause, fix it, verify, and commit, then tell me in a few lines what it
  was. Never stop at the diagnosis to ask whether to apply the fix.
* A plain question ("why does X", "how does Y work") gets an answer, not a
  change.
* Otherwise act. Don't ask "Want me to?" for reversible actions that follow from
  the request. Stop only for destructive or irreversible ones. Never end a turn
  on a plan or a promise.
* No ritual caveat closers. Surface a limitation only when it is a real
  constraint I would hit and would want to decide about.
* Report faithfully. If tests fail, say so with the output. "Done" means
  verified, never "this should work now".
* Never invent an API, flag, path or config key. Look it up (Context7 for
  libraries, per `~/.claude/rules/context7.md`). Find a sibling in the repo and
  mirror it before writing something new.
* Delegate wide exploration to the code-searcher subagent and keep only its
  conclusions. Read narrowly; don't re-read a file you just edited.
* Don't preserve backward compatibility unless I ask. Delete the obsolete path
  instead of wrapping it in a compat shim.
* Build the simplest thing that meets the requirement. No speculative
  abstraction, no config knob with one caller. Decide architecture for the long
  term; the person replacing your stopgap is me, six months on, with no context.
* No temporary hacks or patches left standing. A workaround used to unblock or
  test an idea is fine; once it is confirmed working, turn it into the
  permanent fix in the same task: in the repo, declarative, at the real cause,
  with the hack removed. A live-applied tweak, a hand-edited generated file or
  a manual step that only lives on one machine is not done.
* Use what the project already depends on before adding a package. Don't
  hand-roll date maths, auth, parsing, or retries.
* Write code that reads like the surrounding code. Delete what you replace.
  Complete the change everywhere, callers included, in the same turn. No
  `TODO: implement` stubs presented as done.
* Verify with the narrowest command that proves it. Fix the FIRST error; later
  ones usually cascade. One hypothesis at a time, undoing a failed fix before
  the next. After three genuinely different failures, stop and report.
* Never hardcode SVG. Use the project's icon set (Lucide, Nucleo).
* Ignore GEMINI.md and GEMINI-*.md.

### Commits

Commit when a unit of work is done and verified: a feature, a fix, a refactor
that builds and passes its check. Shipping code without committing it leaves
me to reconstruct what you did; a commit at the end of the task is expected,
not something to ask about. Do not commit half-done work, a checkpoint every
few edits, or a tidy-up that touches nothing behaviourally, and squash into
the existing commit rather than adding "fix typo" on top when the first one
has not been pushed yet. One task, one commit, unless the change genuinely
splits into independent pieces.

### Pushing, building and deploying

Repos owned by CanaryCoders, FormalStudio, KangaCoders or me (`FormalSnake`)
are yours to push once the commit is verified; don't wait for me. The same
goes for the builds, rebuilds, CI runs, releases and deploys that ship that
work to my own machines and services: carry a fix all the way to the place I
hit the bug, then tell me it is live. Check the remote owner with
`git remote get-url origin` before pushing; anything else (forks, upstream
projects, third-party repos) still waits for me to ask. Force-pushing over
commits that aren't yours stays a confirm-first action.

Match the repo's existing style; read recent `git log` first. Default: short
imperative lowercase subject, conventional prefix (`fix(scope): …`) when the
history uses one. No body unless it closes an issue. Never claim co-authorship.

### Hosts and rebuilds

Roles, nix rebuild commands, fspec shipping for e1504g and disk cleanup are in
the `host-ops` skill. Short form: macbook is the always-on dev server, g815 is
the compiler, tester, GPU host and Windows VM host, e1504g is the weak client
and runtime tester (openSUSE under fspec, never NixOS, never compile on it).
Rebuilds are allowed; `git add` new files first. Confirm first before
`nix-collect-garbage -d` or network changes that can cut SSH.

### Subagent model routing

Reasoning-heavy (architecture, root-cause debugging, adversarial review,
synthesis) goes to `opus`; independent review goes to Codex through
`better-call-sol` (`claude-pulse` when Codex hits limits). Execution-heavy (specified implementation, refactors,
broad searches, running tests) goes to `sonnet`. Trivial lookups go to `haiku`.
Use the aliases, never pinned IDs. Agent files in `~/.claude/agents/` declare a
matching `model:` in frontmatter. Every subagent prompt that can reach a git
tree carries the uncommitted-work section above verbatim; a subagent running
`git reset`, `stash`, `checkout --`, `restore` or `clean` is a defect in the
prompt you wrote.

When building AI features, default to the newest models: Fable 5
(`claude-fable-5`), Opus 5 (`claude-opus-5`), Sonnet 5 (`claude-sonnet-5`),
Haiku 4.5 (`claude-haiku-4-5-20251001`).

## Where checkouts live

`~/Developer/ecosystem/` holds my own stack (FormalShell, NativeDesktop,
formalmusic, lynk, FormalSpec, messages, kopuz); anything else sits at
`~/Developer/<repo>`.

### Worktrees: last resort, and you clean up

Work in the main checkout. A worktree or throwaway clone is only for when the
main checkout genuinely can't take the work: another agent is mid-edit there,
or two builds would collide on the same files. "Keeping things tidy" or "a
clean base" is not a reason. A compile check of one changed file is not a
reason either; run it in the checkout you already have.

When you do need one, it goes in `<repo>-wt/<name>` next to the main checkout
(`ecosystem/NativeDesktop-wt/rel-059`), made with `git worktree add` from the
main checkout so it stays listed, never as a loose sibling in `~/Developer` or
`~`. Scripts, logs and screenshots from the run go inside it.

Removing it is part of the same task, not a follow-up: once its commits are
merged or pushed, `git worktree remove <path>`, then `git worktree prune`,
then `rmdir` the `<repo>-wt` directory if it is empty, on whichever host you
made it (g815 and macbook both). A worktree you made and are about to leave
behind is a defect, the same as an uncommitted change. A worktree you did not
make is someone's work in flight: leave it, per the uncommitted-work rule.

Before making one because another agent is in the tree, message that agent
(`ListAgents`, then `t3_thread_send`) and ask what it is
touching and for how long. Often the answer makes the worktree unnecessary:
it is about to commit, it is in other files, or the two of you can take
turns. The same goes for a leftover worktree you find: ask the agent that
owns it whether it still needs it, and remove it if it says no.

## Tooling

`fd` instead of `find`, `rg` instead of `grep`, `jq` for JSON, `bunx` instead
of `npx` for one-off package binaries. `tree` is not
installed. `ls -la` is fine for a single directory. Search with the most
distinctive token you know rather than several vague queries.

## Memory bank

Some repos carry `CLAUDE-activeContext.md`, `CLAUDE-patterns.md`,
`CLAUDE-decisions.md`, `CLAUDE-troubleshooting.md`, `CLAUDE-config-variables.md`.
Read the active context file first where it exists, and maintain them with the
`memory-bank` skill. Never proactively create docs or README files.

## Disk cleanup

One pass, always `-x`: `df -h /`, then `du -xh -d 1` into the largest child.
Delete-without-asking and ask-first lists are in `host-ops`. Stop once the
target is met.
