# appstore-screenshots

Claude Code skill that turns an app codebase plus simulator screenshots into
store-ready App Store screenshot images.

Pipeline: benefit discovery from the codebase, screenshot pairing, then a
deterministic Pillow scaffold (compose.py) enhanced by Nano Banana Pro through
the CanaryLLM gateway (canaryllm.py, async queue with referenceImages).
Style presets in `styles/` (clean, bevel, x-dark); fonts, colors, gradients,
device tilt and layout are all overridable per panel.

Requirements: `python3` with Pillow, SF Pro Display fonts in `/Library/Fonts`
(both wired into the nix config), and a CanaryLLM API key in
`~/.claude/secrets/canaryllm-api-key`.

Replaces the vendored adamlyttleapps/claude-skill-aso-appstore-screenshots,
which needed a separate Gemini MCP server.
