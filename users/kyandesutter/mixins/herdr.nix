{ pkgs, inputs, ... }:
{
  # herdr — terminal workspace manager for AI coding agents.
  # Not in nixpkgs; installed straight from the upstream flake (nixpkgs follows
  # ours, so it builds against this config's pkgs). Replaces the previous
  # imperative `curl … | sh` install that dropped a binary in ~/.local/bin.
  home.packages = [
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # herdr ships a Nix flake but no home-manager module, so manage its config as
  # a plain-text TOML file. Read-only (lives in the nix store); runtime state
  # (sockets, logs, session.json) is written to ~/.config/herdr separately and
  # is untouched by this.
  xdg.configFile."herdr/config.toml".text = ''
    onboarding = false

    [theme]
    name = "catppuccin"

    [ui.toast]
    delivery = "system"

    [ui]
    show_agent_labels_on_pane_borders = true
    agent_panel_scope = "all"
  '';
}
