{ config, lib, pkgs, inputs, osConfig ? { }, ... }:
let
  # Live working-copy path (NOT the nix store).
  # mkOutOfStoreSymlink points at this, so edits in the repo are live without rebuilding.
  claudeSrc = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/claude";

  link = sub: config.lib.file.mkOutOfStoreSymlink "${claudeSrc}/${sub}";

  # The flake host name — the label ssh aliases, rebuild targets and CLAUDE.md
  # itself use. nix-darwin leaves networking.hostName null (the mac's scutil
  # name is "MacBook-Pro-2", which isn't the name anything else calls it), so
  # the sole darwin host falls back to its flake attribute.
  osHostName = (osConfig.networking or { }).hostName or null;
  host = if osHostName == null || osHostName == "" then "macbook" else osHostName;
in
{
  programs.claude-code = {
    enable = true;

    # claude-code-nix instead of pkgs.claude-code: nixpkgs lags upstream by
    # days, and new models are gated on current CLI versions.
    package = inputs.claude-code-nix.packages.${pkgs.system}.default;

    # known_marketplaces.json is left imperative — the CLI's `claude /plugin
    # marketplace add ...` writes it directly, which conflicts with HM-owned
    # symlinks. Trade-off: marketplaces aren't pinned in nix.

    # Settings are read from the repo at build time. Trade-off: edits to settings.json
    # require a rebuild (no live-edit). The file is copied into the store at eval time —
    # required for pure-mode `darwin-rebuild switch`.
    settings = builtins.fromJSON (builtins.readFile ../claude/settings.json);
  };

  home.file = {
    # Memory-bank docs
    ".claude/CLAUDE.md".source                 = link "CLAUDE.md";
    ".claude/AGENTS.md".source                 = link "AGENTS.md";
    ".claude/CLAUDE-cloudflare.md".source      = link "CLAUDE-cloudflare.md";
    ".claude/CLAUDE-cloudflare-mini.md".source = link "CLAUDE-cloudflare-mini.md";

    # Which machine this session is on. CLAUDE.md itself can't carry it: it's one
    # out-of-store symlink into the repo, shared byte-for-byte by all three hosts.
    # ~/.claude/rules/*.md is loaded with the same always-on, user-level status as
    # ~/.claude/CLAUDE.md, so a generated file here reaches every session.
    ".claude/rules/host.md".text = ''
      YOU ARE ON THIS HOST: ${host}
    '';

    # Directory trees (still live-edit symlinks — these don't get rewritten by claude-code)
    ".claude/agents".source   = link "agents";
    ".claude/commands".source = link "commands";
    ".claude/hooks".source    = link "hooks";

    # Plugin metadata (config.json, installed_plugins.json, cache/, data/, marketplaces/,
    # repos/, known_marketplaces.json) stays imperative — claude-code rewrites these via
    # `mv`, which breaks symlinks.
  }
  # skills/ can't be one whole-directory symlink anymore: home-manager's
  # claude-code module (2026-07) installs its generated MCP plugin at
  # ~/.claude/skills/claude-code-home-manager, so HM must own the directory
  # and each repo skill is installed individually.
  #
  # These are STORE COPIES, not mkOutOfStoreSymlink: an out-of-store symlink
  # here pointed ~/.claude/skills/<name> back at the repo, which HM then
  # re-exported into its own generated store dir — a self-referential loop
  # (repo <-> home-manager-files) that ELOOPs and corrupts the working tree.
  # Copying into the store breaks the cycle; the trade-off is that editing a
  # vendored skill now needs a rebuild.
  // lib.mapAttrs' (
    name: _: lib.nameValuePair ".claude/skills/${name}" { source = ../claude/skills + "/${name}"; }
  ) (lib.filterAttrs (name: type:
        type == "directory"
        && name != "claude-code-home-manager")
      (builtins.readDir ../claude/skills));
}
