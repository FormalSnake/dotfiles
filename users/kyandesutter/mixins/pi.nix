{ config, ... }:
let
  # Live working-copy path (NOT the nix store). mkOutOfStoreSymlink points here,
  # so edits in the repo are live without rebuilding. pi re-reads settings,
  # keybindings, extensions and context files on startup / `/reload`.
  piSrc = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/pi";

  # Reuse the claude memory-bank as pi's global context file. pi auto-loads
  # ~/.pi/agent/CLAUDE.md (or AGENTS.md) at startup.
  claudeSrc = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/claude";

  link = path: config.lib.file.mkOutOfStoreSymlink path;
in
{
  home.file = {
    # Global config: settings (extensions list, model defaults) + keybindings
    # (shift+tab freed for mode-cycle; shift+enter / ctrl+j newline).
    ".pi/agent/settings.json".source    = link "${piSrc}/settings.json";
    ".pi/agent/keybindings.json".source = link "${piSrc}/keybindings.json";

    # Auto-read context file (shared with Claude Code).
    ".pi/agent/CLAUDE.md".source = link "${claudeSrc}/CLAUDE.md";

    # Extensions: mode-cycle (plan/normal/auto on shift+tab) and the MCP bridge.
    # Whole directories are symlinked so node_modules (mcp-bridge) and TS sources
    # are picked up live.
    ".pi/agent/extensions/mode-cycle".source = link "${piSrc}/extensions/mode-cycle";
    ".pi/agent/extensions/mcp-bridge".source = link "${piSrc}/extensions/mcp-bridge";
  };
}
