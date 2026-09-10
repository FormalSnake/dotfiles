{ config, lib, pkgs, inputs, osConfig ? { }, ... }:
let
  # Live working-copy path (NOT the nix store).
  # mkOutOfStoreSymlink points at this, so edits in the repo are live without rebuilding.
  claudeSrc = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/claude";

  link = sub: config.lib.file.mkOutOfStoreSymlink "${claudeSrc}/${sub}";

  # Second claude.ai subscription. CLAUDE_CONFIG_DIR keys the on-disk config
  # AND the macOS keychain entry, so the two logins never see each other; the
  # shared config below is symlinked back at the primary profile so both
  # accounts get the same CLAUDE.md, agents, commands, hooks, rules and skills.
  # plugins/ is shared as a whole directory: claude-code rewrites the metadata
  # files inside it with `mv`, which a directory symlink survives (a per-file
  # symlink would not), so both profiles see the same installed plugins.
  pulseDir = ".claude-pulse";
  fromPrimary = sub: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/${sub}";

  # The flake host name: the label ssh aliases, rebuild targets and CLAUDE.md
  # itself use. nix-darwin leaves networking.hostName null (the mac's scutil
  # name is "MacBook-Pro-2", which isn't the name anything else calls it), so
  # the sole darwin host falls back to its flake attribute.
  osHostName = (osConfig.networking or { }).hostName or null;
  host = if osHostName == null || osHostName == "" then "macbook" else osHostName;
in
{
  programs.claude-code = {
    enable = true;

    # claude-code-nix instead of pkgs.claude-code (nixpkgs lags upstream by
    # days, and new models are gated on current CLI versions).
    package = inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;

    # known_marketplaces.json is left imperative (the CLI's `claude /plugin
    # marketplace add ...` writes it directly, which conflicts with HM-owned
    # symlinks). Trade-off: marketplaces aren't pinned in nix.

    # Settings are read from the repo at build time. Trade-off: edits to settings.json
    # require a rebuild (no live-edit). The file is copied into the store at eval time,
    # required for pure-mode `darwin-rebuild switch`.
    settings = builtins.fromJSON (builtins.readFile ../claude/settings.json) // {
      # The Bash tool never runs fish: claude-code rejects an unsupported $SHELL
      # and falls back to zsh. The prompt's "Shell:" line still echoes $SHELL
      # verbatim, so a fish login shell tells the model it is in fish and it
      # writes fish syntax that zsh then rejects. Point $SHELL at the shell that
      # actually runs; fish stays the login shell everywhere else.
      env.SHELL = lib.getExe pkgs.zsh;
    };
  };

  programs.fish.functions.claudepulse = {
    description = "Claude Code signed in to the second claude.ai account";
    body = ''
      CLAUDE_CONFIG_DIR="$HOME/${pulseDir}" claude $argv
    '';
  };

  # .claude.json is the one piece that cannot be symlinked: it carries
  # oauthAccount (per-login) and claude-code rewrites it on nearly every turn.
  # Copy across the two parts that would otherwise be missing from the second
  # profile, user-scope MCP servers and the per-repo trust flags, and leave the
  # rest of the file alone. Runs at rebuild, so a server added to the primary
  # reaches the second account on the next switch.
  home.activation.claudePulseConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    primary="${config.home.homeDirectory}/.claude.json"
    pulse="${config.home.homeDirectory}/${pulseDir}/.claude.json"
    if [ -r "$primary" ]; then
      [ -f "$pulse" ] || run install -m 600 /dev/null "$pulse"
      [ -s "$pulse" ] || echo '{}' > "$pulse"
      run ${lib.getExe pkgs.jq} -s '
        .[0] * {
          mcpServers: (.[1].mcpServers // {}),
          projects: ((.[0].projects // {}) * ((.[1].projects // {})
            | with_entries(select(.value.hasTrustDialogAccepted == true))
            | map_values({ hasTrustDialogAccepted: true })))
        }
      ' "$pulse" "$primary" > "$pulse.hm-tmp"
      run mv "$pulse.hm-tmp" "$pulse"
      run chmod 600 "$pulse"
    fi
  '';

  home.file = {
    # Second-account profile: shared config, separate login.
    "${pulseDir}/CLAUDE.md".source     = fromPrimary "CLAUDE.md";
    "${pulseDir}/AGENTS.md".source     = fromPrimary "AGENTS.md";
    "${pulseDir}/settings.json".source = fromPrimary "settings.json";
    "${pulseDir}/agents".source        = fromPrimary "agents";
    "${pulseDir}/commands".source      = fromPrimary "commands";
    "${pulseDir}/hooks".source         = fromPrimary "hooks";
    "${pulseDir}/rules".source         = fromPrimary "rules";
    "${pulseDir}/skills".source        = fromPrimary "skills";
    "${pulseDir}/plugins".source       = fromPrimary "plugins";

    # Memory-bank docs
    ".claude/CLAUDE.md".source                 = link "CLAUDE.md";
    ".claude/AGENTS.md".source                 = link "AGENTS.md";
    ".claude/CLAUDE-cloudflare.md".source      = link "CLAUDE-cloudflare.md";
    ".claude/CLAUDE-cloudflare-mini.md".source = link "CLAUDE-cloudflare-mini.md";

    # Which machine this session is on. CLAUDE.md itself can't carry it (it's one
    # out-of-store symlink into the repo, shared byte-for-byte by all three hosts).
    # ~/.claude/rules/*.md is loaded with the same always-on, user-level status as
    # ~/.claude/CLAUDE.md, so a generated file here reaches every session.
    ".claude/rules/host.md".text = ''
      YOU ARE ON THIS HOST: ${host}
    '';

    # Directory trees (still live-edit symlinks, these don't get rewritten by claude-code)
    ".claude/agents".source   = link "agents";
    ".claude/commands".source = link "commands";
    ".claude/hooks".source    = link "hooks";

    # Plugin metadata (config.json, installed_plugins.json, cache/, data/, marketplaces/,
    # repos/, known_marketplaces.json) stays imperative (claude-code rewrites these via
    # `mv`, which breaks symlinks).
  }
  # skills/ can't be one whole-directory symlink anymore: home-manager's
  # claude-code module (2026-07) installs its generated MCP plugin at
  # ~/.claude/skills/claude-code-home-manager, so HM must own the directory
  # and each repo skill is installed individually.
  #
  # These are STORE COPIES, not mkOutOfStoreSymlink (an out-of-store symlink
  # here pointed ~/.claude/skills/<name> back at the repo, which HM then
  # re-exported into its own generated store dir, a self-referential loop
  # (repo <-> home-manager-files) that ELOOPs and corrupts the working tree).
  # Copying into the store breaks the cycle; the trade-off is that editing a
  # vendored skill now needs a rebuild.
  // lib.mapAttrs' (
    name: _: lib.nameValuePair ".claude/skills/${name}" { source = ../claude/skills + "/${name}"; }
  ) (lib.filterAttrs (name: type:
        type == "directory"
        && name != "claude-code-home-manager")
      (builtins.readDir ../claude/skills));
}
