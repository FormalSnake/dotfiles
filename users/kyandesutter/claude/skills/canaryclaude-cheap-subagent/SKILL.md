---
name: canaryclaude-cheap-subagent
description: Offload mechanical, well-specified coding work (refactors, renames, boilerplate, formatting passes, applying a pattern across many files) to `canaryclaude`, which is Claude Code routed through the user's own CanaryLLM proxy. Cheap and fast enough to fan out — pick a small/fast model like `gemini/gemini-2.5-flash` (or `gemini-2.5-flash-lite`, or local `lmstudio/qwen3.6-35b-a3b`) for the subagent. Use whenever a task is execution-heavy but reasoning-light — code transformations where you already know the answer and just need the typing done. Use even if the user hasn't named canaryclaude: if you're about to do a dozen near-identical edits, or apply a clearly-specified refactor across multiple files, this skill applies. Always background canaryclaude calls and parallelize them — even fast models take 15–60s per task, so it shines when many run concurrently while you do real reasoning work.
---

# canaryclaude: cheap subagent via CanaryLLM

`canaryclaude` is a fish function that runs `claude` (Claude Code) with the user's `CANARYLLM_API_KEY` and `ANTHROPIC_BASE_URL` pointed at `canaryllm.canarycoders.es`. From there, the `--model` flag picks the actual backend — anything CanaryLLM proxies, including cheap Gemini Flash models and the user's local LMStudio Qwen.

Why this skill exists:

- **Cheap**: routed through the user's own infra — invoke as often as you want
- **Slower than direct Claude**: 15s for trivial edits, 30s–1min for moderate, longer for complex
- **Same tool set as Claude Code**: Read/Write/Edit/Bash/Glob/Grep, edits files autonomously
- **Good at**: applying a clearly-specified code change
- **Bad at**: deciding *what* change to make, debugging, design choices, anything that needs cross-file reasoning — the smaller the model, the more this matters

Think of a canaryclaude subagent as a fast typist who can't read your mind. You do the thinking; it does the typing.

## When to use canaryclaude

Use it when **you already know the answer** and the remaining work is mechanical. Good fits:

- "Rename `foo` to `bar` in these 8 files" — one canaryclaude call per file, in parallel
- "Add type annotations to every function in `module.py`"
- "Convert this class component to a function component using these specific hooks"
- "Apply this lint fix pattern across all files matching X"
- "Generate boilerplate test stubs for each function in `lib/`"
- "Reformat this 600-line file to use early returns instead of nested ifs"

Bad fits — do these yourself or with a real (frontier-model) subagent:

- "Figure out why this test is failing" — needs reasoning
- "Design an API for X" — needs judgment
- "Refactor this module to be cleaner" — too vague, the subagent won't know what "cleaner" means
- "Find the bug in this function" — small models will confidently produce wrong output
- Anything spanning more context than the chosen model can comfortably hold

## Invocation pattern

`canaryclaude` is a fish function, not a binary on `PATH`. The Bash tool defaults to bash/zsh, so wrap calls in `fish -c`:

```bash
fish -c "canaryclaude -p --model <model> --permission-mode bypassPermissions '<very explicit prompt>'" < /dev/null
```

Key flags (all of these are real `claude` flags — `canaryclaude` forwards them):

- `-p` / `--print` — non-interactive (process and exit)
- `--model <id>` — required. Pick by task:
  - `gemini/gemini-2.5-flash` — sensible default, fast and capable enough for most mechanical edits
  - `gemini/gemini-2.5-flash-lite` — when you want the cheapest/fastest possible
  - `lmstudio/qwen3.6-35b-a3b` — fully local, free, slow (~60–90s), single-file scope
  - `gemini/gemini-2.5-pro` — escalation if a flash model keeps failing the spec
  - `openai/gpt-4.1` — alternative mid-tier when you want a non-Gemini, non-Claude option (e.g. you suspect a model-family quirk is biting you)
  - `anthropic/claude-sonnet-4-5` — closest thing to "just use Claude" while still going through the proxy; reach for it when the task is on the edge of mechanical-vs-reasoning and you'd otherwise give up and do it yourself
- `--permission-mode bypassPermissions` — required so the subagent can Edit/Write without prompting. The whole point is autonomy.
- `< /dev/null` on the end — suppresses the "no stdin received in 3s" warning.

Optional but useful:
- `--allowed-tools "Read Edit Write"` — restrict to the tools you want it touching
- `--add-dir <path>` — give it access to a directory outside cwd if needed
- `--max-turns <n>` — cap iteration count (useful for keeping a runaway in check)

**Always background canaryclaude calls.** They block for tens of seconds. Use the Bash tool's `run_in_background: true` and continue working. When you need many edits, spawn them all in one assistant message (multiple Bash tool calls in parallel) — they'll run concurrently.

## Writing prompts for canaryclaude

The whole reason this is "cheap" is that you're picking a small/fast model. Small models cannot infer; they cannot fill in gaps; they will not push back on a bad instruction. You must give a complete, ordered, unambiguous spec.

### The rule of thumb

A good prompt reads like a code review comment that already tells you the diff. A bad prompt reads like a Slack message to a senior engineer.

### Required elements in every prompt

1. **What file(s) to read** — name them explicitly. Don't say "the auth module"; say "Read `src/auth/login.ts`."
2. **Exactly what to change** — list each change as a numbered step. Quote identifiers and strings verbatim.
3. **Exactly what to write** — name the output file. Usually the same file you read.
4. **What NOT to do** — small models tend to add comments, docstrings, explanations, or extra refactors unless told not to. Spell out the forbidden behaviors.
5. **What to keep removed** — be explicit when deleting code. Small models will sometimes leave dead lines (e.g. an orphaned `return` after the new return), so say "delete the old loop and the old return statement" rather than just "replace the loop."

### Example: bad vs good prompt

**Bad** (vague, will produce slop):
```
make fetch_user better
```

**Good** (will produce exactly the diff you wanted):
```
Read src/api/users.py. Refactor the fetch_user function with these specific changes:
1. Move the `import requests` statement to the top of the file
2. Change the URL construction from string concatenation to an f-string
3. Replace the `if r.status_code == 200` check with `r.raise_for_status()`
4. Return `r.json()` directly instead of assigning to `data` first; delete the old `data = r.json()` and `return data` lines and the `else: return None` branch
Write the refactored code back to src/api/users.py.
Do not add docstrings. Do not add comments. Do not change any other function.
Output only code.
```

### Patterns that work

- **Read-then-write**: always have the subagent `Read X` first, then specify the change, then `Write back to X`. It needs to load the file to edit it.
- **Numbered steps**: small models follow ordered lists more reliably than prose.
- **Quote literals**: when you mention a name, wrap it in backticks.
- **Be explicit about deletion**: "delete the old <thing>" prevents leftover dead code.
- **Negative constraints**: "Do not add comments. Do not add docstrings. Do not change other functions." The subagent loves to over-deliver.
- **Single file scope**: one canaryclaude call per file. Spawn many in parallel rather than asking one to touch several.

## Parallelizing canaryclaude calls

The whole point is throughput. When you have N mechanical edits, fire N calls in parallel:

```
[in one assistant turn, spawn N Bash tool calls with run_in_background: true]
Bash 1: fish -c "canaryclaude -p --model gemini/gemini-2.5-flash --permission-mode bypassPermissions 'Read src/a.ts. <explicit instructions>. Write back.'" < /dev/null
Bash 2: fish -c "canaryclaude -p --model gemini/gemini-2.5-flash --permission-mode bypassPermissions 'Read src/b.ts. <explicit instructions>. Write back.'" < /dev/null
...
Bash N: fish -c "canaryclaude -p --model gemini/gemini-2.5-flash --permission-mode bypassPermissions 'Read src/n.ts. <explicit instructions>. Write back.'" < /dev/null
```

Then keep working. You'll be notified as each completes. After all are done, read the modified files and verify the changes are correct.

## Verification is mandatory

Small models will occasionally produce wrong output that *looks* right — orphaned lines after a delete, slightly wrong identifier capitalization, a missing import, an extra refactor you didn't ask for. After every batch:

1. Run `git diff` on the touched files
2. Run the relevant tests / typechecker / linter
3. Read at least one of the modified files yourself

If a file went sideways, **fix it yourself or re-prompt with a tighter spec** — don't argue with the subagent by sending follow-ups; just throw out the bad output (`git checkout -- path`) and redo it with a better prompt.

## Picking the model

Rough ladder, cheapest/fastest at the top:

- `gemini/gemini-2.5-flash-lite` — extremely simple tasks, maximum throughput
- `gemini/gemini-2.5-flash` — **default**. Fast, cheap, capable enough for clearly-specified edits
- `lmstudio/qwen3.6-35b-a3b` — fully local on the user's own box. Slowest, but zero external calls — pick when the work is sensitive or offline-friendly. Single-file scope only.
- `openai/gpt-4.1` — alternative mid-tier when a Gemini model is stubbornly misreading the spec; sometimes a different model family gets it on the first try
- `gemini/gemini-2.5-pro` — escalate here when a flash model keeps failing
- `anthropic/claude-sonnet-4-5` — top of the ladder through the proxy. Reach for it when the task is on the edge of mechanical-vs-reasoning. If you'd genuinely consider doing it yourself rather than dispatching, this is the point on the ladder where the subagent becomes worth it again.

If even Sonnet 4.5 is failing the same spec, the task isn't actually mechanical — stop dispatching and do it yourself.

## Quick mental model

- canaryclaude = `claude` pointed at the user's CanaryLLM proxy
- The `--model` flag picks how cheap/fast the subagent is
- Use it when you've already decided what to do
- Slow per call → only worth it in parallel
- Cheap → fire as many as you want
- Always verify with `git diff`
- If you find yourself writing a second clarifying prompt, the first one wasn't explicit enough; reset the file and redo it
- Must invoke through `fish -c` (it's a fish function carrying the API key from agenix)
- Must pass `--permission-mode bypassPermissions` so it can actually edit files
- Append `< /dev/null` to silence the stdin warning
