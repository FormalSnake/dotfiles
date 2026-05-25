{ config, ... }:
let
  # Live working-copy path (NOT the nix store).
  # mkOutOfStoreSymlink points at this, so edits in the repo are live without rebuilding.
  claudeSrc = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/claude";

  link = sub: config.lib.file.mkOutOfStoreSymlink "${claudeSrc}/${sub}";
in
{
  # Install the `claude` CLI from nixpkgs via the HM module. Settings/agents/commands/
  # etc. stay symlinked below (live-edit), so we leave the module's settings/context/
  # *Dir options unset to avoid clobbering those symlinks.
  programs.claude-code.enable = true;

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

    # Plugin metadata (config.json, known_marketplaces.json, installed_plugins.json,
    # cache/, data/, marketplaces/, repos/) stays imperative — claude-code rewrites
    # these via `mv`, which breaks HM symlinks and trips activation on every rebuild.
    # See follow-up plan to manage marketplaces declaratively via programs.claude-code.marketplaces.
  };
}
