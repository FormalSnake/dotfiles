---
name: refine
description: Switch the refine prompt-rewrite hook between auto (every prompt, the default), on (opt in with #refine) and off, or show its status and recent log. Use when the user says /refine, asks to turn prompt refining on or off, or asks whether the local model rewrite is working.
---

# refine

The hook lives at `~/.config/nix/users/kyandesutter/claude/marketplace/plugins/refine/bin/refine.py`
and runs through `uv`. Modes:

- `auto`: every prompt at or above `auto_min_chars` is rewritten (default); `#skip` bypasses one prompt.
- `on`: only prompts containing `#refine` are rewritten.
- `off`: the hook exits immediately.

Run exactly one of these, then report the command's output verbatim:

```
uv run --quiet --script ~/.config/nix/users/kyandesutter/claude/marketplace/plugins/refine/bin/refine.py mode on
uv run --quiet --script ~/.config/nix/users/kyandesutter/claude/marketplace/plugins/refine/bin/refine.py mode auto
uv run --quiet --script ~/.config/nix/users/kyandesutter/claude/marketplace/plugins/refine/bin/refine.py mode off
uv run --quiet --script ~/.config/nix/users/kyandesutter/claude/marketplace/plugins/refine/bin/refine.py status
```

`status` prints the mode, model and the last five log lines. With no argument
(or `status`) default to `status`. `warm` pulls the Ollama model and the
LLMLingua-2 weights; run it only when `status` reports one of them missing.
