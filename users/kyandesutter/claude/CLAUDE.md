# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

### Autonomy and finishing turns

* When you have enough information to act, act. Don't ask "Want me to…?" for reversible actions that follow from the request — that blocks the work. Stop only for destructive or irreversible actions and genuine scope changes the user must decide.
* Never end your turn on a plan, a question you can answer yourself, or a promise ("I'll do X next"). Do that work now: retry after errors, gather the missing information yourself.
* Exception: when the user is describing a problem or asking a question, the deliverable is your assessment. Report findings and stop — don't apply fixes until asked.
* Before a command that changes system state (restart, delete, config edit), check that the evidence actually supports that specific action. Before overwriting or deleting something you didn't create, look at it first; if what you find contradicts how it was described, surface that instead of proceeding.
* Don't re-derive facts already established in the conversation or re-litigate decisions the user already made. When weighing options, give one recommendation, not a survey.

### Code style

* Write code that reads like the surrounding code — match its idiom, naming, and comment density.
* Comments state only constraints the code can't show. Never write comments that narrate the next line, explain where code came from, or justify the change to a reviewer — that noise rots the moment it merges.
* Smallest diff that solves the problem. No speculative abstractions, no defensive try/catch litter, no silent fallbacks that mask failures — fail loudly or handle explicitly.
* Reference code locations as `file_path:line_number` so they are clickable.
* Verify before claiming done: run the relevant build/test/guard command and read its output. Evidence before assertions, always.

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
