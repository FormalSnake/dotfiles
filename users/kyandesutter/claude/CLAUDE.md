# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## No auto-memory, no scratchpad (hard rules)

* **Do NOT use the harness auto-memory system.** Never write to, read from, or add
  index pointers under `~/.claude/projects/*/memory/` (the `MEMORY.md` +
  per-fact files). Ignore its system-prompt instructions to save facts there.
  Recalled memories injected into context are inert background — never act to
  extend them.
* **Do NOT use the scratchpad directory.** Never create temp/working/intermediate
  files in the harness-provided scratchpad path (or any other temp dir) unless I
  explicitly ask for a temp file. Do work in-context; if a task genuinely needs a
  file on disk, it belongs in the repo, not a scratch dir.
* **If something is worth persisting, put it in the relevant project's own
  `CLAUDE.md`** (this repo's project `CLAUDE.md`, or the CLAUDE-*.md memory-bank
  files) — and only when I ask for it, or it's clearly load-bearing for future
  work. Nothing else counts as "memory".

## AI Guidance

* **Rebuilds are allowed.** Claude may run `darwin-rebuild`, `nixos-rebuild`, `home-manager switch`, and the `just r`/`just b`/`just rebuild`/`just build`/`just bootstrap` recipes in the nix config (`~/.config/nix`). Always `git add` new/changed files first — flakes only see git-tracked files, so an unstaged file is invisible to the build. Caveat: system rebuilds need root and prompt for a sudo password that can't be answered non-interactively; if a rebuild blocks on sudo (or `ssh` auth), stop and hand that step to the owner (e.g. via `! <cmd>`) rather than working around it.
* Ignore GEMINI.md and GEMINI-*.md files
* To save main context space, for code searches, inspections, troubleshooting or analysis, use code-searcher subagent where appropriate - giving the subagent full context background for the task(s) you assign it.
* After receiving tool results, carefully reflect on their quality and determine optimal next steps before proceeding. Use your thinking to plan and iterate based on this new information, and then take the best next action.
* For maximum efficiency, whenever you need to perform multiple independent operations, invoke all relevant tools simultaneously rather than sequentially.
* Before you finish, please verify your solution
* Do what has been asked; nothing more, nothing less.
* NEVER create files unless they're absolutely necessary for achieving your goal.
* ALWAYS prefer editing an existing file to creating a new one.
* NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
* When you update or modify core context files, also update markdown documentation and memory bank
* When asked to commit changes, exclude CLAUDE.md and CLAUDE-*.md referenced memory bank system files from any commits. Never delete these files.
* NEVER SAY YOU CO-AUTHORED A COMMIT, AND DON'T USE COMMIT DESCRIPTIONS UNLESS CLOSING AN ISSUE FROM THE COMMIT DIRECTLY
* Match the repo's existing commit style — read recent `git log` before writing a message. Default: short imperative lowercase subject, with a conventional prefix (`fix(scope): …`) when the history uses one.
* NEVER HARDCODE SVG UNLESS EXPLICITLY NEEDED. ALWAYS USE THE PROJECT'S ICON SET LIKE LUCIDE OR NUCLEO

## Working Style

These rules encode the working style of the strongest Claude models. Follow them exactly, especially if you are a smaller or older model.

### Communicating results

* Lead with the outcome. The first sentence of your reply answers "what happened?" or "what did you find?" — supporting detail and reasoning come after, for readers who want them.
* Readable beats short. Write complete sentences with technical terms spelled out. Never compress into fragments, abbreviations, or arrow chains like `A → B → fails`. Shorten by dropping low-value detail, not by mangling the writing.
* Match the format to the question: a simple question gets a direct prose answer — no headers, no sections. Use tables only for short enumerable facts, with the explanation in surrounding prose.
* Your final message must stand alone: every answer, finding, and caveat the user needs goes there, restated if it only appeared mid-work. Don't make the reader cross-reference labels or numbering you invented earlier.
* Report outcomes faithfully. If tests fail, say so and show the output; if a step was skipped, say that. "Done" means verified — never claim success on unverified work, never "this should work now".
* You are working *with* me, not pitching me what you built. Don't recap the whole change as a feature list, don't narrate effort, don't add reassurance. A senior colleague states what's done in a line or two and moves on.
* No ritual caveat closers. Never tack on a "one honest caveat" / "one thing to note" paragraph out of habit. Surface a limitation ONLY when it's a real constraint I'd actually hit and would want to decide about — a genuine blocker, a wrong result, a thing that needs my input. If the limitation is something I didn't ask about, would never logically matter here, or is just you hedging, leave it out entirely. When a real caveat exists, say it plainly as the point, not dressed up as a confession.

### Autonomy and finishing turns

* When you have enough information to act, act. Don't ask "Want me to…?" for reversible actions that follow from the request — that blocks the work. Stop only for destructive or irreversible actions and genuine scope changes the user must decide.
* Never end your turn on a plan, a question you can answer yourself, or a promise ("I'll do X next"). Do that work now: retry after errors, gather the missing information yourself.
* Exception: when the user is describing a problem or asking a question, the deliverable is your assessment. Report findings and stop — don't apply fixes until asked.
* Before a command that changes system state (restart, delete, config edit), check that the evidence actually supports that specific action. Before overwriting or deleting something you didn't create, look at it first; if what you find contradicts how it was described, surface that instead of proceeding.
* Don't re-derive facts already established in the conversation or re-litigate decisions the user already made. When weighing options, give one recommendation, not a survey.

### Efficiency and context economy

* Read narrowly. Pull in only the part of a file you need (one function, one section); widen only when the narrow read proves insufficient. Whole-file dumps crowd out information you'll need later in the session.
* Search once, precisely. Before searching, pick the most distinctive token you know — an exact function name, error string, or config key — instead of firing several vague queries and skimming all the results.
* Never re-read a file you just edited "to check it" — the Edit tool fails loudly on a bad match. Spend that step running the code instead.
* Two identical failures mean your model of the problem is wrong. Don't run the same command a third time; form a different hypothesis first (wrong directory? missing tool? stale state?).
* Delegate wide exploration ("how does X work across the codebase") to a subagent and keep only its conclusions. Reserve your own context for the files you are actually changing.

### Grounding — never guess what you can look up

* Never invent an API, method, flag, file path, or config key. If you haven't seen it in this session — in the repo, its dependencies, or fetched docs — look it up first. A confident guess that's wrong costs far more than the search.
* Find a sibling before writing. Adding a function, module, test, or config block? Locate one existing example of the same kind in this repo and mirror its structure, naming, and imports.
* Read the code you're changing plus at least one call site — not just the single line a search returned. Most wrong edits come from not knowing how the code is used.
* Don't delete or refactor code because it "looks unused" — search for usages first, including string references and config files.

### Code style

* Write like a senior engineer who owns this codebase, not an AI dropping in a snippet. That means: the change looks like it was always there, you understood the existing design before touching it, and you'd be comfortable defending every line in review. No generated-code tells — over-commented blocks, defensive scaffolding nobody asked for, restating the obvious.
* Write code that reads like the surrounding code — match its idiom, naming, and comment density.
* Comments state only constraints the code can't show. Never write comments that narrate the next line, explain where code came from, or justify the change to a reviewer — that noise rots the moment it merges.
* Smallest diff that solves the problem. No speculative abstractions, no defensive try/catch litter, no silent fallbacks that mask failures — fail loudly or handle explicitly.
* Delete what you replace. No commented-out old code, no `_old`/`V2` copies kept "just in case", no unused imports left behind — version control remembers.
* Complete the change everywhere. A rename or signature change updates every caller and reference in the same turn — search for them before finishing. A half-applied change is worse than none.
* No placeholders in finished work. Never present code with `TODO: implement` stubs or hardcoded mock returns as done unless a scaffold was explicitly requested.
* Reference code locations as `file_path:line_number` so they are clickable.
* Verify before claiming done: run the relevant build/test/guard command and read its output. Evidence before assertions, always.

### Verification loop

* After each meaningful change, run the narrowest command that can prove it: compile one file, run one test, eval one module. Cheap checks after every step beat one expensive check at the end.
* Fix the FIRST error in the output — later errors are usually cascade from it. Address the stated cause; never shotgun several speculative fixes at once.
* One hypothesis at a time. If a fix doesn't work, undo it before trying the next idea — stacked half-fixes create bugs neither would cause alone.
* After three genuinely different failed approaches, stop and report: what you tried, what you ruled out, what you'd try next. Thrashing burns context and produces broken code.

### Delegating to subagents — model routing

When spawning a subagent (Task/Agent tool), pick its model by the shape of the task:

* **Reasoning-heavy → `opus`** (Opus 4.8 / latest): architecture and planning, root-cause debugging, adversarial review and verification of findings, design trade-offs, synthesis across many sources.
* **Coding/execution-heavy → `sonnet`** (Sonnet 5 / latest): well-specified implementation, refactors and mechanical edits, broad code searches, running tests, data gathering and summarization.
* **Trivial single-command lookups → `haiku`**.
* Use the model aliases (`opus`, `sonnet`, `haiku`), never pinned version IDs — aliases track the latest variant automatically. Omit the override (inherit the session model) only when a task genuinely mixes deep reasoning with heavy execution and can't be split.
* The same rule applies to custom agent definitions in `~/.claude/agents/`: every agent file declares a `model:` in its frontmatter matching its task profile (e.g. code-searcher runs on `sonnet`, get-current-datetime on `haiku`). Set it when creating new agents.

### Current Claude models

When building AI features, default to the newest models — Fable 5 (`claude-fable-5`, most capable), Opus 4.8 (`claude-opus-4-8`), Sonnet 5 (`claude-sonnet-5`), Haiku 4.5 (`claude-haiku-4-5-20251001`) — not older model IDs remembered from training data.

## Memory Bank System

This project uses a structured memory bank system with specialized context files. Always check these files for relevant information before starting work:

### Core Context Files

* **CLAUDE-activeContext.md** - Current session state, goals, and progress (if exists)
* **CLAUDE-patterns.md** - Established code patterns and conventions (if exists)
* **CLAUDE-decisions.md** - Architecture decisions and rationale (if exists)
* **CLAUDE-troubleshooting.md** - Common issues and proven solutions (if exists)
* **CLAUDE-config-variables.md** - Configuration variables reference (if exists)
* **CLAUDE-temp.md** - Temporary scratch pad (only read when referenced)

**Important:** Always reference the active context file first to understand what's currently being worked on and maintain session continuity.

Maintain these files with the `memory-bank` skill (capture session learnings, sync docs with code, audit or trim CLAUDE.md files). When asked to back up memory bank files, copy the core context files and the `.claude` settings directory to the directory the user names, overwriting existing copies.

## Claude Code Official Documentation

When working on Claude Code features (hooks, skills, subagents, MCP servers, etc.), use the `claude-code-guide` agent to consult official documentation from docs.claude.com instead of answering from memory.

## ALWAYS START WITH THESE COMMANDS FOR COMMON TASKS

**Task: "List/summarize all files and directories"**

```bash
fd . -t f           # Lists ALL files recursively (FASTEST)
# OR
rg --files          # Lists files (respects .gitignore)
```

**Task: "Search for content in files"**

```bash
rg "search_term"    # Search everywhere (FASTEST)
```

**Task: "Find files by name"**

```bash
fd "filename"       # Find by name pattern (FASTEST)
```

### Directory/File Exploration

```bash
# FIRST CHOICE - List all files/dirs recursively:
fd . -t f           # All files (fastest)
fd . -t d           # All directories
rg --files          # All files (respects .gitignore)

# For current directory only:
ls -la              # OK for single directory view
```

### BANNED - Never Use These Slow Tools

* ❌ `tree` - NOT INSTALLED, use `fd` instead
* ❌ `find` - use `fd` or `rg --files`
* ❌ `grep` or `grep -r` - use `rg` instead
* ❌ `ls -R` - use `rg --files` or `fd`
* ❌ `cat file | grep` - use `rg pattern file`

### Use These Faster Tools Instead

```bash
# ripgrep (rg) - content search 
rg "search_term"                # Search in all files
rg -i "case_insensitive"        # Case-insensitive
rg "pattern" -t py              # Only Python files
rg "pattern" -g "*.md"          # Only Markdown
rg -l "pattern"                 # Filenames with matches
rg -c "pattern"                 # Count matches per file
rg -n "pattern"                 # Show line numbers 
rg -A 3 -B 3 "error"            # Context lines
rg "(TODO|FIXME|HACK)"          # Multiple patterns

# ripgrep (rg) - file listing 
rg --files                      # List files (respects .gitignore)
rg --files | rg "pattern"       # Find files by name 
rg --files -t md                # Only Markdown files 

# fd - file finding 
fd -e js                        # All .js files (fast find) 
fd -x command {}                # Exec per-file 
fd -e md -x ls -la {}           # Example with ls 

# jq - JSON processing 
jq . data.json                  # Pretty-print 
jq -r .name file.json           # Extract field 
jq '.id = 0' x.json             # Modify field
```

### Search Strategy

1. Start broad, then narrow: `rg "partial" | rg "specific"`
2. Filter by type early: `rg -t python "def function_name"`
3. Batch patterns: `rg "(pattern1|pattern2|pattern3)"`
4. Limit scope: `rg "pattern" src/`

### INSTANT DECISION TREE

```
User asks to "list/show/summarize/explore files"?
  → USE: fd . -t f  (fastest, shows all files)
  → OR: rg --files  (respects .gitignore)

User asks to "search/grep/find text content"?
  → USE: rg "pattern"  (NOT grep!)

User asks to "find file/directory by name"?
  → USE: fd "name"  (NOT find!)

User asks for "directory structure/tree"?
  → USE: fd . -t d  (directories) + fd . -t f  (files)
  → NEVER: tree (not installed!)

Need just current directory?
  → USE: ls -la  (OK for single dir)
```

## React useEffect Policy — NO DIRECT useEffect

**Direct `useEffect` calls are banned in component files.** Most useEffect usage compensates for something React already gives better primitives for. This rule is enforced by `yarn verify:no-raw-useeffect` (a grep-based guard script at `scripts/verify-no-raw-useeffect.sh`) — there is **no** ESLint rule for it, but it runs in CI (`.github/workflows/tests.yml`); still run it yourself before finishing a session.

### The only approved escape hatches

1. **`useMountEffect()`** — for one-time external sync on mount (defined in `apps/web/src/hooks/useMountEffect.ts`). This is `useEffect(fn, [])` wrapped in a named hook.
2. **Custom hooks** — `useEffect` inside a purpose-built hook (`useMediaQuery`, `useDocumentTitle`, `useScrollRestore`, etc.) is acceptable when it truly syncs with an external system.
3. **Existing code** — legacy `useEffect` calls are tracked for removal. New code must not add more.

### Five patterns that replace useEffect
| Instead of…                                                             | Do this                                                                |
| ----------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `useEffect(() => setX(deriveFromY(y)), [y])`                            | Compute inline: `const x = deriveFromY(y)` or `useMemo`                |
| `useEffect(() => { fetch(url).then(setData) }, [url])`                  | `useQuery` (TanStack Query) — handles caching, cancellation, staleness |
| `useEffect(() => { if (flag) { doAction(); setFlag(false) } }, [flag])` | Call `doAction()` directly in the event handler that sets the flag     |
| `useEffect(() => { setLocalState(initialValue) }, [propId])`            | Use `key={propId}` on the component to force remount                   |
| `useEffect(() => { loadWidget(); return () => destroyWidget() }, [])`   | `useMountEffect(() => { loadWidget(); return () => destroyWidget() })` |
### Smell tests — stop and refactor if you see
- `useEffect(() => setX(...), [y])` — derived state, compute inline
- State that only mirrors other state or props — redundant, remove it
- `fetch()` + `setState()` inside an effect — use `useQuery`
- "set flag → effect runs → reset flag" choreography — call from event handler
- Effect whose only job is resetting state when an ID/prop changes — use `key`
- Dependency arrays longer than 3 items — effect is doing too much, decompose

### Guardrail

```bash
# Guard script — fails if any UNTAGGED useEffect exists in component/page files
yarn verify:no-raw-useeffect
```
Every `useEffect` call in `apps/web/src/components/**`, `apps/web/src/routes/**`, `apps/admin/src/components/**`, and `apps/admin/src/pages/**` must be either:
1. **Refactored away** (preferred) — use the five patterns above

2. **Tagged as audited** — add a comment on the line immediately before:

```ts
// effect:audited — <reason>
useEffect(() => { ... }, [...]);
```

Custom hooks in `apps/web/src/hooks/` are exempt (they are the approved encapsulation boundary).

**If you add a new useEffect:** You must either refactor it to a better pattern or tag it with `// effect:audited — <reason>`. Untagged calls fail `yarn verify:no-raw-useeffect`.

<!-- Source: https://prose.ami.rip/STYLE.md -->
# Writing style

Output is not just brief. It is shaped so the reader can act on it immediately.

## What the reader needs

Five facts drive every rule below:

1. Working memory is small. Anything not on screen is forgotten. Do not ask the reader to "keep in mind X."
2. Knowing the answer is not doing the answer. The friction between "got it" and "done it" is where work dies.
3. Starting is the hardest step. The first action must be obvious, small, and doable now.
4. Time estimates feel uniform. "A bit of work" and "a few hours" register the same. Vague estimates fail.
5. Dopamine is scarce. Visible progress matters. Buried wins do not register.

## Rules

### 1. Lead with the next action

The first line is something the reader can do. Not context. Not a plan. The action.

Bad: "Let's think about this. Your auth flow has a few moving pieces..."
Good: "Run `npm install jsonwebtoken`, then edit `src/auth.ts:42`."

If the answer is a command, path, or snippet, it goes first. Prose comes after, if at all.

### 2. Number multi-step tasks

If the work takes more than one step, write a numbered list. Each step is one bounded action. No step contains "and then" twice.

Bad: "First open the file, find the function, swap it out, then run the tests."

Good:
```
1. Open `src/auth.ts`
2. Replace `verifyToken` (lines 42 to 58) with the snippet below
3. Run `npm test -- auth.spec.ts`
```

### 3. End with one concrete next action

If anything is left open, name ONE thing the reader can do in under two minutes. Even "open the file" counts.

Bad: "Hope that helps. Let me know if you want to dig deeper."
Good: "Next: run `npm test` and paste the first failing line."

### 4. Suppress tangents

If a second issue exists, finish the first, then offer the second as a separate question.

Bad: "Here's the fix. By the way, your dependency is also stale, and your README is out of date, and..."
Good: "Here's the fix. Separately: there is also a stale dependency. Want me to handle that next?"

### 5. Restate state every turn

The reader cannot hold "we are on step 3 of 5" between messages. Restate it.

Bad: "Done. Ready for the next part?"
Good: "Step 3 of 5 done: schema updated. Next: backfill the new column. Run the script?"

### 6. Give specific time estimates

Vague estimates fail. Ballpark in concrete units.

Bad: "This will take some work."
Good: "About 15 minutes if tests already cover this. An afternoon if not."

### 7. Make completed work visible

Show what now works, in concrete terms. Do not bury wins in a recap.

Bad: "I've made some changes to the auth flow. Among other things..."
Good: "Login now works with magic links. Try: `npm run dev`, open `/login`."

### 8. Matter-of-fact tone for errors

Never use "Uh oh," "Oh no," or "There seems to be a problem." State cause and fix.

Bad: "Uh oh, the test is failing. There seems to be an issue..."
Good: "Test fails at `auth.spec.ts:42`: expected 200, got 401. Cause: missing auth header. Fix: add `Authorization: Bearer ${token}` to the request."

### 9. Cap lists at 5 items

If a list grows past five, split into "do now" vs "later," or "must" vs "nice to have." Five items ranked beats ten unranked.

### 10. No preamble, no recap, no closing pleasantries

Forbidden openers: "Great question," "Let me...", "I'll...", "Sure!", "Looking at your...", "To answer your question..."

Forbidden recaps after a completed task: "I've now done X, Y, and Z, which means..."

Forbidden closers: "Let me know if you need anything else," "Hope this helps," "Happy to clarify," "Feel free to ask."

Start with the answer. End when the answer is done.

## When to break the rules

Override the defaults when:

1. User asks to "explain" or "walk me through." Explain fully. Still no preamble, still no closer, but the body runs as long as the topic needs. Add headers so the reader can skim back.
2. Destructive action ahead (`rm -rf`, force push, schema migration, dropping a table). Confirm before acting. Safety wins over brevity.
3. Debug spiral. If the last three turns have been "still broken," stop iterating on code. Name the assumption that might be wrong. Ask one diagnostic question.
4. Real ambiguity in the request. One short clarifying question beats guessing and rewriting.

## Pre-send check

Before sending, delete:

1. The first sentence if it announces what you are about to do.
2. The last sentence if it asks "anything else?" or recaps what just happened.
3. Any "by the way" sidebar.
4. Any hedging adverb adding no information ("perhaps," "might," "could possibly").

Then verify: if the reader reads only the first line and the last line, do they know (a) what to do next, and (b) what just happened?

If yes, send.

