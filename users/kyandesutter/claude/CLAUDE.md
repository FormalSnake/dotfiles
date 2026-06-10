# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## AI Guidance

* **NEVER REBUILD. Only the owner (kyandesutter) may run rebuilds.** Do not run `darwin-rebuild`, `nixos-rebuild`, `home-manager switch`, `just r`/`just b`/`just rebuild`/`just build`/`just bootstrap`, or any build/activation/switch command — not even build-only variants — in the nix config (`~/.config/nix`) or anywhere else. When nix changes are ready, `git add` the new/changed files (flakes only see git-tracked files), document what changed, then stop and let the owner rebuild manually.
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
* NEVER HARDCODE SVG UNLESS EXPLICITLY NEEDED. ALWAYS USE THE PROJECT'S ICON SET LIKE LUCIDE OR NUCLEO

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

### Memory Bank System Backups

When asked to backup Memory Bank System files, you will copy the core context files above and @.claude settings directory to directory @/path/to/backup-directory. If files already exist in the backup directory, you will overwrite them.

## Claude Code Official Documentation

When working on Claude Code features (hooks, skills, subagents, MCP servers, etc.), use the `claude-docs-consultant` skill to selectively fetch official documentation from docs.claude.com.

## Project Overview



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
rg -1 "pattern"                 # Filenames with matches
rg -c "pattern"                 # Count matches per file
rg -n "pattern"                 # Show line numbers 
rg -A 3 -B 3 "error"            # Context lines
rg " (TODO| FIXME | HACK)"      # Multiple patterns

# ripgrep (rg) - file listing 
rg --files                      # List files (respects •gitignore)
rg --files | rg "pattern"       # Find files by name 
rg --files -t md                # Only Markdown files 

# fd - file finding 
fd -e js                        # All •js files (fast find) 
fd -x command {}                # Exec per-file 
fd -e md -x ls -la {}           # Example with ls 

# jq - JSON processing 
jq. data.json                   # Pretty-print 
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

**Direct `useEffect` calls are banned in component files.** Most useEffect usage compensates for something React already gives better primitives for. This rule is enforced by `yarn verify:no-raw-useeffect` (a grep-based guard script at `scripts/verify-no-raw-useeffect.sh`) — there is **no** ESLint rule for it and it is not wired into CI; run it yourself before finishing a session.

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
Every `useEffect` call in `apps/web/src/components/**` and `apps/web/src/pages/**` must be either:
1. **Refactored away** (preferred) — use the five patterns above

2. **Tagged as audited** — add a comment on the line immediately before:

```ts
// effect:audited — <reason>
useEffect(() => { ... }, [...]);
```

Custom hooks in `apps/web/src/hooks/` are exempt (they are the approved encapsulation boundary).

**If you add a new useEffect:** You must either refactor it to a better pattern or tag it with `// effect:audited — <reason>`. Untagged calls fail `yarn verify:no-raw-useeffect`.
