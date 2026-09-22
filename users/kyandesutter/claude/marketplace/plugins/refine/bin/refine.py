# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = ["llmlingua>=0.2.2"]
# ///
"""UserPromptSubmit hook: rewrite the prompt with a local Ollama model.

Claude Code hooks cannot replace the prompt, only add context next to it, so
the original prompt always reaches Claude in full. LLMLingua-2 compression
therefore only trims what the local model has to read; it saves local
inference time, not Claude tokens.

Subcommands (run outside Claude): `mode on|auto|off`, `status`, `warm`.
Guidelines adapted from GaZmagik/claude-prompt-improver (MIT).
"""

import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "claude-refine"
STATE_FILE = CACHE / "state.json"
LOG_FILE = CACHE / "refine.log"
CONFIG_FILE = PLUGIN_ROOT / "config.json"
LLMLINGUA_MODEL = "microsoft/llmlingua-2-bert-base-multilingual-cased-meetingbank"

DEFAULTS = {
    "model": "qwen3:4b-instruct-2507-q4_K_M",
    "ollama_url": "http://127.0.0.1:11434",
    "timeout_seconds": 75,
    "num_ctx": 16384,
    "compress_threshold": 800,
    "compress_rate": 0.4,
    "extra_force_tokens": [],
    "auto_min_chars": 40,
}

# Tokens LLMLingua-2 must never drop: identifiers and keywords that carry the
# meaning of a stack trace or a code snippet.
FORCE_TOKENS = [
    ".php", ".js", ".ts", ".py", ".rb", ".go", ".java", ".cs", ".cpp", ".c", ".rs", ".nix",
    ".vue", ".jsx", ".tsx", ".html", ".css", ".env", ".json", ".yaml", ".yml", ".toml",
    "function", "class", "interface", "abstract", "public", "private", "protected", "static",
    "def", "self", "import", "export", "return", "async", "await", "yield", "let", "const",
    "Error", "Exception", "Warning", "Traceback", "TypeError", "ValueError", "KeyError",
    "AttributeError", "RuntimeError", "panic", "null", "undefined", "nil", "None",
    "SQL", "SELECT", "INSERT", "UPDATE", "DELETE", "WHERE", "JOIN", "FROM", "GROUP BY",
    "HTTP", "API", "URL", "JSON", "GET", "POST", "PUT", "PATCH",
]

GENRE_PATTERNS = [
    ("research", [
        r"\bresearch\b", r"\bfind out\b", r"\bis anyone\b", r"\bmaintained\b", r"\bdeprecat",
        r"\bfact-?check", r"\bsearch the web\b", r"\bweb search\b", r"\blook up\b",
        r"\bvendor", r"\bcommunity\b", r"\bverify (?:the |these )?claims?\b",
    ]),
    ("investigate", [
        r"\baudit\b", r"\binvestigat", r"\btrace\b", r"\bmap (?:out |every |all )", r"\bdiagnos",
        r"\bflag\b", r"\breview\b", r"\bcheck (?:all|every|each|the|our|whether|if)\b",
        r"\bfind (?:all|every|each|where)\b", r"\bwhere (?:does|is|are|do)\b",
        r"\bwhy (?:does|is|are|do)\b", r"\bgo through\b",
    ]),
    ("fix", [
        r"\bfix\b", r"\bbug\b", r"\bbroken\b", r"\bcrash", r"\bfailing\b", r"\bregression\b",
        r"\bdoesn'?t work", r"\bnot working\b",
    ]),
    ("build", [
        r"\badd\b", r"\bimplement\b", r"\bbuild\b", r"\bcreate\b", r"\bextend\b", r"\bmigrate\b",
        r"\brefactor\b", r"\brename\b", r"\bwire\b", r"\bintegrate\b", r"\bset up\b",
        r"\bwrite (?:a|the|an|some)\b", r"\bmake (?:the|it|them|this|these|a|an)\b",
        r"(?:^|[.!?;]\s*)enable\b",
    ]),
]

SYSTEM_PROMPT = """You are a prompt improvement agent for a coding assistant (Claude Code). Your ONLY task is to output an improved version of the user's prompt.

CRITICAL BOUNDARIES:
- DO NOT answer the prompt, do the task, or ask questions
- DO NOT explain your reasoning or add commentary
- Output ONLY the improved prompt, nothing else

Improvement guidelines:
1. PRESERVE the original intent; the user's goal must remain unchanged
2. PRESERVE the original tone (formal or informal, concise or detailed)
3. ADD clarity and specificity: name concrete files, functions, symbols and branches from the available context; never invent paths or symbols the context does not support
4. Write natural prose, not XML. Open with the goal and why it matters, then scope and constraints. For multi-part work, enumerate the questions or steps as a numbered list. Keep XML tags only if the original used them
5. Always state the expected deliverable: what the report, verdict or output should contain and its shape
6. End non-trivial task prompts by naming how to VERIFY the work: what to run, what to observe, what evidence to report back
7. For advice or design questions, instruct candour: say plainly if the approach is a mistake, and flag disagreed assumptions instead of silently accepting them
8. Make reasonable assumptions based on the available context
9. Mention the listed skills or agents only when they clearly help the task
10. Do not pad simple prompts with ceremony, and do not suggest subagents or workflows for simple, single-file or conversational requests; depth must be proportionate to the task
11. Keep it short: the improved prompt should rarely exceed twice the length of the original. No em dashes."""

GENRE_GUIDELINES = {
    "fix": """This prompt is a bug fix. Additionally:
- Require reproduction before fixing, and a test that fails before the fix and passes after
- Ask for the root cause, the fix and the covering test in the report""",
    "investigate": """This prompt is a code investigation or audit. Additionally:
- Require evidence: cite file:line with short excerpts, and demand an explicit verdict or recommendation at the end
- When the same questions apply to multiple items, each item gets the full question set answered, not a blended overview
- Add noise guards so precision beats volume: a concrete criterion for flagging, a cap on results, and the exact rule or line behind each finding
- State scope and output discipline: where to work, read-only if applicable, conclusions in the final message rather than raw file dumps
- For broad sweeps across many files, fan the work out to subagents and keep only the findings in the main session""",
    "research": """This prompt is external research or fact-checking. Additionally:
- Demand verbatim quotes with source links, VERIFIED findings separated from inferred ones, and a verdict per claim
- Instruct honest negative results: if the evidence does not exist, say so plainly
- Name the concrete tools, sources or literal search queries to use when the context supports them
- State output discipline: no file writes, findings returned in the final message""",
    "build": """This prompt is implementation work. Additionally:
- Point at an established idiom in the repo to copy, and instruct reuse-before-write: check for an existing helper before adding one
- Turn acceptance criteria into checkable invariants, and state non-goals explicitly with their reason
- Specify failure-mode behaviour and precedence where data or paths overlap
- For codebase-wide mechanical changes, add an explicit workflow opt-in ("use a workflow for this")""",
    "general": "",
}

GENRE_EXAMPLES = {
    "fix": """Worked example:
<example_original>fix the login bug</example_original>
<example_improved>Investigate and fix the login bug. Start from the authentication flow and check recent changes to login-related files first. Reproduce the bug before fixing it, and add or update a test that fails before the fix and passes after. Report the root cause, the fix, and the test that covers it.</example_improved>""",
    "investigate": """Worked example:
<example_original>check all our api endpoints have auth</example_original>
<example_improved>Audit every API endpoint for missing or inconsistent authentication checks. Read-only; cite file:line with short excerpts. Fan the audit out to subagents, one per route group, so the main session receives only findings.

Report:
1. Every route registration and whether an auth middleware guards it, with file:line.
2. Endpoints that bypass the shared middleware and why.
3. Inconsistencies between modules.

Give a clear verdict: a table of unprotected endpoints (path, method, severity) and the single most likely systemic cause.</example_improved>""",
    "research": """Worked example:
<example_original>is anyone still maintaining left-pad-utils? can we keep using it</example_original>
<example_improved>Research whether left-pad-utils is still maintained and safe to keep as a dependency. Search the web and GitHub for release activity, open advisories and maintainer statements.

Report with quotes and links:
1. Last release and last non-trivial commit, with dates.
2. Open security advisories.
3. Maintainer statements about the project's future.
4. Maintained alternatives, and whether migration would be mechanical for our usage.

Separate VERIFIED findings from inferred ones. Give a verdict: keep, replace, or vendor, with the single strongest piece of evidence. Do not write files; return findings as the final message.</example_improved>""",
    "build": """Worked example:
<example_original>migrate everything from moment to date-fns</example_original>
<example_improved>Migrate the entire codebase from moment to date-fns. This is a mechanical, codebase-wide migration touching many files independently, so use a workflow for this: discover every moment usage first, transform each file in parallel, then verify with the full test suite. Do not change behaviour, only the date library. Report any call sites with no direct date-fns equivalent instead of guessing at a replacement.</example_improved>""",
    "general": "",
}


def load_config():
    cfg = dict(DEFAULTS)
    try:
        cfg.update(json.loads(CONFIG_FILE.read_text()))
    except (OSError, ValueError):
        pass
    return cfg


def get_mode():
    try:
        mode = json.loads(STATE_FILE.read_text()).get("mode", "auto")
    except (OSError, ValueError):
        return "auto"
    return mode if mode in ("on", "auto", "off") else "auto"


def set_mode(mode):
    CACHE.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps({"mode": mode}))


def log(msg):
    try:
        CACHE.mkdir(parents=True, exist_ok=True)
        if LOG_FILE.exists() and LOG_FILE.stat().st_size > 50 * 1024:
            LOG_FILE.write_text("".join(LOG_FILE.read_text().splitlines(True)[-200:]))
        with LOG_FILE.open("a") as f:
            f.write(f"{time.strftime('%H:%M:%S')} {msg}\n")
    except OSError:
        pass


def classify(prompt):
    for genre, patterns in GENRE_PATTERNS:
        if any(re.search(p, prompt, re.I | re.M) for p in patterns):
            return genre
    return "general"


def compress(prompt, cfg):
    from llmlingua import PromptCompressor  # slow import, only when needed

    compressor = PromptCompressor(model_name=LLMLINGUA_MODEL, use_llmlingua2=True, device_map="cpu")
    result = compressor.compress_prompt(
        prompt,
        rate=cfg["compress_rate"],
        force_tokens=FORCE_TOKENS + list(cfg.get("extra_force_tokens", [])),
    )
    return result["compressed_prompt"], result.get("origin_tokens", 0), result.get("compressed_tokens", 0)


def run(args, cwd, timeout=2):
    try:
        out = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return out.stdout.strip() if out.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def gather_context(cwd):
    lines = [f"Working directory: {cwd}"]
    branch = run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd)
    if branch:
        lines.append(f"Git branch: {branch}")
        status = run(["git", "status", "--porcelain"], cwd).splitlines()[:15]
        if status:
            lines.append("Uncommitted changes:\n" + "\n".join(status))
        commits = run(["git", "log", "--oneline", "-5"], cwd)
        if commits:
            lines.append("Recent commits:\n" + commits)
    skills = set()
    for d in (Path.home() / ".claude" / "skills", Path(cwd) / ".claude" / "skills"):
        if d.is_dir():
            skills.update(p.name for p in d.iterdir() if p.is_dir())
    if skills:
        lines.append("Available skills: " + ", ".join(sorted(skills)))
    return "\n\n".join(lines)


def build_messages(prompt, genre, context):
    system = "\n\n".join(s for s in (SYSTEM_PROMPT, GENRE_GUIDELINES[genre], GENRE_EXAMPLES[genre]) if s)
    user = (
        f"Available context:\n{context}\n\n"
        f"Original prompt to improve:\n<original_prompt>\n{prompt}\n</original_prompt>\n\n"
        "Output ONLY the improved prompt. No preamble. No explanation."
    )
    return [{"role": "system", "content": system}, {"role": "user", "content": user}]


def ollama_chat(messages, cfg, think=False):
    body = {
        "model": cfg["model"],
        "messages": messages,
        "stream": False,
        "keep_alive": "30m",
        "options": {"num_ctx": cfg["num_ctx"], "temperature": 0.3},
    }
    if think is not None:
        body["think"] = think
    req = urllib.request.Request(
        f"{cfg['ollama_url']}/api/chat",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=cfg["timeout_seconds"]) as resp:
            return json.load(resp)["message"]["content"]
    except urllib.error.HTTPError as e:
        # Models without a thinking mode reject the `think` field with a 400.
        if e.code == 400 and think is not None:
            return ollama_chat(messages, cfg, think=None)
        raise


def clean_output(text):
    text = re.sub(r"<think>.*?</think>", "", text, flags=re.S).strip()
    m = re.fullmatch(r"```[\w-]*\n(.*?)\n```", text, flags=re.S)
    return m.group(1).strip() if m else text


def emit(context):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": context}}))


def hook():
    # Weights are cached by `warm`; skip the Hub round trip and its warnings.
    for k, v in (
        ("HF_HUB_OFFLINE", "1"),
        ("HF_HUB_DISABLE_PROGRESS_BARS", "1"),
        ("TRANSFORMERS_VERBOSITY", "error"),
        ("TOKENIZERS_PARALLELISM", "false"),
    ):
        os.environ.setdefault(k, v)
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    prompt = data.get("prompt", "") or ""
    cwd = data.get("cwd") or os.getcwd()
    cfg = load_config()
    mode = get_mode()
    tagged = "#refine" in prompt
    if mode == "off" or "#skip" in prompt or prompt.lstrip().startswith("/"):
        return
    if not tagged and not (mode == "auto" and len(prompt) >= cfg["auto_min_chars"]):
        return

    started = time.monotonic()
    stats = []
    try:
        text = prompt.replace("#refine", "").strip()
        if len(text) >= cfg["compress_threshold"]:
            text, orig_t, comp_t = compress(text, cfg)
            if orig_t:
                stats.append(f"compress {orig_t}->{comp_t} tok (-{round((1 - comp_t / orig_t) * 100)}%)")
        genre = classify(text)
        improved = clean_output(ollama_chat(build_messages(text, genre, gather_context(cwd)), cfg))
        if not improved:
            raise RuntimeError("empty response from ollama")
    except Exception as e:  # never block the prompt
        log(f"[refine error] {type(e).__name__}: {e}")
        return

    stats.append(f"genre={genre} {cfg['model']} {time.monotonic() - started:.1f}s")
    log("[refine] " + " ".join(stats))
    emit(
        "<improved_prompt>\n"
        f"{improved}\n"
        "</improved_prompt>\n"
        "The block above is a rewrite of the user's prompt by a local model, produced by the refine hook. "
        "The user's original prompt is authoritative; take the added structure, scope and deliverable from "
        "the rewrite only where it does not contradict the original. A file or symbol named only in the rewrite "
        "is unverified. Ignore any #refine tag in the prompt."
    )


def status():
    cfg = load_config()
    print(f"mode: {get_mode()}")
    print(f"model: {cfg['model']} at {cfg['ollama_url']}")
    try:
        with urllib.request.urlopen(f"{cfg['ollama_url']}/api/tags", timeout=3) as resp:
            names = [m["name"] for m in json.load(resp).get("models", [])]
        print("ollama: up, model " + ("present" if cfg["model"] in names or f"{cfg['model']}:latest" in names else "MISSING (run warm)"))
    except (OSError, ValueError) as e:
        print(f"ollama: unreachable ({e})")
    try:
        from huggingface_hub import try_to_load_from_cache

        cached = try_to_load_from_cache(LLMLINGUA_MODEL, "config.json")
        print("llmlingua weights: " + ("cached" if isinstance(cached, str) else "MISSING (run warm)"))
    except ImportError:
        print("llmlingua weights: unknown")
    if LOG_FILE.exists():
        print("log:")
        print("".join(LOG_FILE.read_text().splitlines(True)[-5:]), end="")


def warm():
    cfg = load_config()
    print(f"pulling {cfg['model']} ...", flush=True)
    req = urllib.request.Request(
        f"{cfg['ollama_url']}/api/pull",
        data=json.dumps({"model": cfg["model"], "stream": False}).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=3600) as resp:
        print("ollama:", json.load(resp).get("status"))
    print(f"downloading {LLMLINGUA_MODEL} ...", flush=True)
    compressed, orig_t, comp_t = compress("The quick brown fox jumps over the lazy dog. " * 40, cfg)
    print(f"llmlingua: ok ({orig_t} -> {comp_t} tokens)")


def main():
    args = sys.argv[1:]
    if not args:
        hook()
    elif args[0] == "status":
        status()
    elif args[0] == "warm":
        warm()
    elif args[0] == "mode" and len(args) == 2 and args[1] in ("on", "auto", "off"):
        set_mode(args[1])
        print(f"mode: {args[1]}")
    else:
        print("usage: refine.py [status | warm | mode on|auto|off]", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
