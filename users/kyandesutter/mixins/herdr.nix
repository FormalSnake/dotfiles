{ config, pkgs, inputs, ... }:
let
  # herdr only ships two catppuccin variants — `catppuccin` (mocha/dark) and
  # `catppuccin-latte` (light); it has no frappe/macchiato themes. Map our
  # global catppuccin.flavor onto those: latte -> light, anything else -> dark.
  # herdr's config.toml has no light/dark "auto" key (unlike ghostty/neovim), so
  # this is a static follow of the flavor, not a runtime macOS-appearance swap.
  herdrTheme =
    if config.catppuccin.flavor == "latte" then "catppuccin-latte" else "catppuccin";
in
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
    name = "${herdrTheme}"

    [ui.toast]
    delivery = "system"

    [ui]
    show_agent_labels_on_pane_borders = true
    agent_panel_scope = "all"
  '';
}
