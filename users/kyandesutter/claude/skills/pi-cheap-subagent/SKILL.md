---
name: pi-cheap-subagent
description: Offload mechanical, well-specified coding work (refactors, renames, boilerplate, formatting passes, applying a pattern across many files) to the local `pi` CLI running `canary/lmstudio/qwen3.6-27b-mlx`. Use whenever a task is execution-heavy but reasoning-light — code transformations where you already know the answer and just need the typing done. Use even if the user hasn't named pi: if you're about to do a dozen near-identical edits, or apply a clearly-specified refactor across multiple files, this skill applies. Always background pi calls and parallelize them — the model is slow (30s–2min per task) but cheap (runs on our own servers), so it shines when many tasks run concurrently while you do real reasoning work.
---

# pi: cheap local coding subagent

`pi` is a CLI agent (like `claude -p`) that runs a local 27B Qwen coding model on our own servers. It has its own Read/Write/Edit/Bash tools and edits files autonomously. The model is:

- **Cheap**: runs on our hardware, free to invoke as often as you want
- **Slow**: 30s for trivial edits, 1–2min for moderate ones, longer for complex
- **Tiny context**: 32.8K tokens total, 8.2K max output — one file at a time, not a whole codebase
- **Good at**: applying a clearly-specified code change
- **Bad at**: deciding *what* change to make, debugging, design choices, anything that needs cross-file reasoning

Think of pi as a fast typist who can't read your mind. You do the thinking; pi does the typing.

## When to use pi

Use pi when **you already know the answer** and the remaining work is mechanical. Good fits:

- "Rename `foo` to `bar` in these 8 files" — one pi call per file, in parallel
- "Add type annotations to every function in `module.py`"
- "Convert this class component to a function component using these specific hooks"
- "Apply this lint fix pattern across all files matching X"
- "Generate boilerplate test stubs for each function in `lib/`"
- "Reformat this 600-line file to use early returns instead of nested ifs"

Bad fits — do these yourself or with a real subagent:

- "Figure out why this test is failing" — needs reasoning
- "Design an API for X" — needs judgment
- "Refactor this module to be cleaner" — too vague, pi won't know what "cleaner" means
- "Find the bug in this function" — pi will confidently produce wrong output
- Anything spanning >1 file's worth of context that pi has to hold in its head at once

## Invocation pattern

```bash
pi -p --model canary/lmstudio/qwen3.6-27b-mlx "<very explicit prompt>"
```

Key flags:
- `-p` — non-interactive (process and exit)
- `--model canary/lmstudio/qwen3.6-27b-mlx` — required, this is the local model
- Optional: `--tools read,write,edit` to restrict what pi can do
- Optional: `--no-context-files` to skip loading CLAUDE.md (faster startup, less noise for tiny tasks)

**Always background pi calls.** They block for 30s–2min. Use the Bash tool's `run_in_background: true` and continue working. When you need many edits, spawn them all in one message (multiple Bash tool calls in parallel) — pi will run them concurrently.

## Writing prompts for pi

pi is a small model. It cannot infer; it cannot fill in gaps; it will not push back on a bad instruction. You must give it a complete, ordered, unambiguous spec.

### The rule of thumb

A good pi prompt reads like a code review comment that already tells you the diff. A bad pi prompt reads like a Slack message to a senior engineer.

### Required elements in every prompt

1. **What file(s) to read** — name them explicitly. Don't say "the auth module"; say "Read `src/auth/login.ts`."
2. **Exactly what to change** — list each change as a numbered step. Quote identifiers and strings verbatim.
3. **Exactly what to write** — name the output file. Usually the same file you read.
4. **What NOT to do** — pi tends to add comments, docstrings, explanations, or extra refactors unless told not to. Spell out the forbidden behaviors.

### Example: bad vs good prompt

**Bad** (pi will produce slop or freeze):
```
make fetch_user better
```

**Good** (pi will produce exactly the diff you wanted):
```
Read src/api/users.py. Refactor the fetch_user function with these specific changes:
1. Move the `import requests` statement to the top of the file
2. Change the URL construction from string concatenation to an f-string
3. Replace the `if r.status_code == 200` check with `r.raise_for_status()`
4. Return `r.json()` directly instead of assigning to `data` first
Write the refactored code back to src/api/users.py.
Do not add docstrings. Do not add comments. Do not change any other function.
Output only code.
```

### Patterns that work

- **Read-then-write**: always have pi `Read X` first, then specify the change, then `Write back to X`. Pi needs to load the file to edit it.
- **Numbered steps**: pi follows ordered lists more reliably than prose.
- **Quote literals**: when you mention a name, wrap it in backticks. Pi loses track of identifiers in long sentences.
- **Negative constraints**: "Do not add comments. Do not add docstrings. Do not change other functions." Pi loves to over-deliver.
- **Single file scope**: one pi call per file. Spawn many in parallel rather than asking one to touch several.

## Parallelizing pi calls

The whole point of pi is throughput. When you have N mechanical edits, fire N pi calls in parallel:

```
[in one assistant turn, spawn N Bash tool calls with run_in_background: true]
Bash 1: pi -p --model canary/lmstudio/qwen3.6-27b-mlx "Read src/a.ts. <explicit instructions>. Write back."
Bash 2: pi -p --model canary/lmstudio/qwen3.6-27b-mlx "Read src/b.ts. <explicit instructions>. Write back."
...
Bash N: pi -p --model canary/lmstudio/qwen3.6-27b-mlx "Read src/n.ts. <explicit instructions>. Write back."
```

Then keep working. You'll be notified as each completes. After all are done, read the modified files and verify the changes are correct — pi can hallucinate, especially under vague prompts, so always spot-check the diffs (`git diff`).

## Verification is mandatory

The model is small and will occasionally produce wrong output that *looks* right. After every batch of pi edits:

1. Run `git diff` on the touched files
2. Run the relevant tests / typechecker / linter
3. Read at least one of the modified files yourself

If a file went sideways, **fix it yourself or re-prompt with a tighter spec** — don't argue with pi by sending follow-ups; just throw out the bad output and redo it with a better prompt.

## Quick mental model

- pi ≈ a fast typing assistant with no memory and no judgment
- Use it when you've already decided what to do
- Slow per call → only worth it in parallel
- Cheap → fire as many as you want
- Always verify with `git diff`
- If you find yourself writing a second clarifying prompt, the first one wasn't explicit enough; redo it
