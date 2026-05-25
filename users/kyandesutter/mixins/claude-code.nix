{ config, pkgs, ... }:
let
  # Live working-copy path (NOT the nix store).
  # mkOutOfStoreSymlink points at this, so edits in the repo are live without rebuilding.
  claudeSrc = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/claude";

  link = sub: config.lib.file.mkOutOfStoreSymlink "${claudeSrc}/${sub}";

  # Declarative marketplaces. Each entry is pinned to a specific commit.
  # To update: `nix run nixpkgs#nix-prefetch-github -- <owner> <repo>` and paste rev/hash.
  marketplaces = {
    claude-code-marketplace = pkgs.fetchFromGitHub {
      owner = "ananddtyagi";
      repo = "claude-code-marketplace";
      rev = "b643305146890bda9b2e694d2c42206ae4d0a4df";
      hash = "sha256-BnH8+reZQRy4st+5zwA1EEDLIc2nVIp8CVBizUIkjXo=";
    };
    claude-plugins-official = pkgs.fetchFromGitHub {
      owner = "anthropics";
      repo = "claude-plugins-official";
      rev = "1b527e2ee74e6dbd198e22cd41701c3b6f47dfec";
      hash = "sha256-zKNCeUQoCVZaJfP+eVmFD9G6du8Iu8p7TZPBcdF3ujs=";
    };
    obsidian-skills = pkgs.fetchFromGitHub {
      owner = "kepano";
      repo = "obsidian-skills";
      rev = "553ef99aa3306dd23f268e1ba9af752577684f69";
      hash = "sha256-KwmnZrHkl/LqMLF+P0YnIqEpL3lGa6DSRUTgqYK1fes=";
    };
    claude-plugin-tmux-notifications = pkgs.fetchFromGitHub {
      owner = "kaiiserni";
      repo = "claude-plugin-tmux-notifications";
      rev = "f9bb68a5041385959e36dd6b88a1e753aea0da64";
      hash = "sha256-NSwxUaui3HU5PuqziItH7vVZPkgFltNAmqiAsU4InqI=";
    };
    claude-code-plugins = pkgs.fetchFromGitHub {
      owner = "anthropics";
      repo = "claude-code";
      rev = "39e853e4074d90f27afdfb7ea601e0fc378bd0c5";
      hash = "sha256-wBp8SlJ/4dxup/P584MM9nke5CtMtciPn5NvrEQr8iM=";
    };
    claude-plugin-desktop-notifications = pkgs.fetchFromGitHub {
      owner = "formalsnake";
      repo = "claude-plugin-desktop-notifications";
      rev = "710c9b882350910600257ce6dd0fccd0530ffeea";
      hash = "sha256-4tVpXjhz2HW71X7Y2wD6J68I4afqcOV8iJN+PbEoTEw=";
    };
    expo-plugins = pkgs.fetchFromGitHub {
      owner = "expo";
      repo = "skills";
      rev = "956a92b9a0018989d7a0002a2b2a525d741867c2";
      hash = "sha256-2FBDqjUY0KzSHtXxq0ChF1fCk1iaEgpO3Ug3hZsi2QM=";
    };
  };
in
{
  programs.claude-code = {
    enable = true;

    # Marketplaces are now declarative — known_marketplaces.json is generated from this
    # attrset and points each installLocation at a /nix/store fetchFromGitHub path.
    # Adding a new marketplace = add an entry above + rebuild. The CLI can no longer
    # `claude /plugin marketplace add ...` (the file is a /nix/store symlink).
    inherit marketplaces;

    # Settings are read from the repo at build time. Trade-off: edits to settings.json
    # require a rebuild (no live-edit). HM-module rewrites settings.json to inject
    # $schema and extraKnownMarketplaces from `marketplaces` above.
    # Path literal (not "${claudeSrc}/..." string) so the file is copied into the
    # store at eval time — required for pure-mode `darwin-rebuild switch`.
    settings = builtins.fromJSON (builtins.readFile ../claude/settings.json);
  };

  home.file = {
    # Memory-bank docs
    ".claude/CLAUDE.md".source                 = link "CLAUDE.md";
    ".claude/AGENTS.md".source                 = link "AGENTS.md";
    ".claude/CLAUDE-cloudflare.md".source      = link "CLAUDE-cloudflare.md";
    ".claude/CLAUDE-cloudflare-mini.md".source = link "CLAUDE-cloudflare-mini.md";

    # Directory trees (still live-edit symlinks — these don't get rewritten by claude-code)
    ".claude/agents".source   = link "agents";
    ".claude/commands".source = link "commands";
    ".claude/hooks".source    = link "hooks";
    ".claude/skills".source   = link "skills";

    # Plugin metadata (config.json, installed_plugins.json, cache/, data/, marketplaces/,
    # repos/) stays imperative — claude-code rewrites these via `mv`, which breaks symlinks.
    # known_marketplaces.json is managed declaratively by programs.claude-code.marketplaces.
  };
}
