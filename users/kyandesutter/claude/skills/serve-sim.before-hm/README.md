# serve-sim skill

A portable [Agent Skill](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview) that teaches AI coding agents to drive an Apple Simulator via [serve-sim](https://github.com/EvanBacon/serve-sim) (by Evan Bacon).

Works in Claude Code, Cursor, Codex CLI, Gemini CLI, GitHub Copilot, and any other tool that supports the open Agent Skills standard.

## What it does

Once installed, your agent knows how to:

- Tap at normalized coordinates (`serve-sim tap`).
- Send multi-touch / drag / swipe gestures with the correct JSON shape.
- Press the six valid hardware buttons (`home`, `swipe_home`, `app_switcher`, `lock`, `siri`, `side_button`).
- Rotate the simulator (`portrait`, `portrait_upside_down`, `landscape_left`, `landscape_right`).
- Inject a synthetic camera feed (placeholder, image, video, or live webcam) into a specific app.
- Toggle CoreAnimation debug overlays (blended layers, off-screen rendering, slow animations, …).
- Simulate a memory warning.
- Discover the running stream's URL and read the simulator's accessibility tree to find UI elements.

It also teaches the agent the **gotchas** (use `tap`, not `gesture`, for plain taps), the **prerequisites** (macOS, Xcode CLI tools, Node 18+, macOS 14+ for camera), and **anti-patterns** to avoid.

## Install

### Claude Code

```sh
/plugin marketplace add malopezr7/serve-sim-skill
/plugin install serve-sim
```

### Any agent that supports the Agent Skills standard (Cursor, Codex CLI, Gemini CLI, …)

```sh
bunx add-skill malopezr7/serve-sim-skill
# or
npx skills add malopezr7/serve-sim-skill
```

### Manual install

Clone this repo into your agent's skills directory:

```sh
git clone https://github.com/malopezr7/serve-sim-skill ~/.claude/skills/serve-sim
# or for other agents: ~/.agents/skills/serve-sim, ~/.cursor/skills/serve-sim, etc.
```

The skill is a folder with a `SKILL.md` file plus reference documents. No build step.

## Prerequisites on the user's machine

The agent will check these for you, but for reference:

- macOS host (any recent version).
- Xcode command line tools (`xcode-select --install`).
- Node.js 18+.
- macOS 14+ if you want camera injection.
- At least one booted iOS, iPad, or Apple Watch simulator.

`serve-sim` itself is invoked via `npx serve-sim` — no global install required.

## How it's structured

```
serve-sim/
├── SKILL.md                          (loaded when the skill triggers)
├── references/
│   ├── gestures.md                   (gesture JSON, edges, multi-touch, recipes)
│   ├── buttons-rotation.md           (the six buttons, the four orientations)
│   ├── camera.md                     (camera injection: sources, mirroring, hot-swap)
│   ├── ca-debug.md                   (CoreAnimation debug flags)
│   ├── endpoints.md                  (HTTP + WebSocket surface)
│   └── workflows.md                  (end-to-end recipes)
├── scripts/
│   ├── check-prereqs.sh              (verify host satisfies requirements)
│   └── ensure-running.sh             (idempotent start of the helper)
└── evals/
    └── evals.json                    (5 test prompts for agent quality)
```

Following Anthropic's recommended structure: short SKILL.md, references one level deep, executable scripts that the agent can run without loading their source into context.

## Designed around progressive disclosure

- Discovery: only the `name` and `description` from the frontmatter cost tokens at startup.
- Activation: when the agent decides the task matches, it reads `SKILL.md` (~250 lines).
- Execution: it reads only the reference files relevant to the current task.

This keeps context usage low across hundreds of installed skills.

## Source of truth

Every claim in this skill (the six button names, the four orientations, the gesture JSON shape, the edge values, the HTTP endpoints) was verified against the serve-sim source in `EvanBacon/serve-sim` at the time of authoring. The skill does not invent behavior the CLI does not actually expose.

Verified against serve-sim `0.1.28`.

## Contributing

Found a divergence between this skill and serve-sim's actual behavior? Open an issue or PR.

Want to suggest a new workflow recipe? Add it to `references/workflows.md` with an explanation of when an agent would use it.

## License

Apache-2.0, matching serve-sim itself.

## Acknowledgements

- [Evan Bacon](https://x.com/Baconbrix) — author of [serve-sim](https://github.com/EvanBacon/serve-sim).
- [Anthropic Agent Skills](https://github.com/anthropics/skills) — the open standard this skill targets.
