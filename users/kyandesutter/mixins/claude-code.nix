{ config, ... }:
let
  # Live working-copy path (NOT the nix store).
  # mkOutOfStoreSymlink points at this, so edits in the repo are live without rebuilding.
  claudeSrc = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/claude";

  link = sub: config.lib.file.mkOutOfStoreSymlink "${claudeSrc}/${sub}";
in
{
  home.file = {
    # Memory-bank docs
    ".claude/CLAUDE.md".source                 = link "CLAUDE.md";
    ".claude/AGENTS.md".source                 = link "AGENTS.md";
    ".claude/CLAUDE-cloudflare.md".source      = link "CLAUDE-cloudflare.md";
    ".claude/CLAUDE-cloudflare-mini.md".source = link "CLAUDE-cloudflare-mini.md";

    # Global settings (not settings.local.json — that's machine-local)
    ".claude/settings.json".source = link "settings.json";

    # Directory trees
    ".claude/agents".source   = link "agents";
    ".claude/commands".source = link "commands";
    ".claude/hooks".source    = link "hooks";
    ".claude/skills".source   = link "skills";

    # Plugin metadata (cache/, data/, marketplaces/, repos/ stay imperative)
    ".claude/plugins/config.json".source              = link "plugins/config.json";
    ".claude/plugins/known_marketplaces.json".source  = link "plugins/known_marketplaces.json";
    ".claude/plugins/installed_plugins.json".source   = link "plugins/installed_plugins.json";
  };
}
