{ config, pkgs, inputs, ... }:
let
  flexoki = import ./flexoki/palette.nix;
  inherit (flexoki) base accents;
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

    # Pin Flexoki Dark via [theme.custom]. The "terminal" theme reads the host
    # terminal's palette through OSC colour queries at runtime; those don't
    # round-trip over SSH/mosh, so remotely herdr fell back to defaults and
    # rendered raw-ANSI harsh. Static tokens sourced from the one Flexoki
    # palette (users/kyandesutter/mixins/flexoki/palette.nix) need no OSC, so
    # they hold up over SSH, and Flexoki Dark's soft off-white text on a lifted
    # b950 panel keeps contrast low. Base "catppuccin" only backstops any token
    # this override doesn't name.
    [theme]
    name = "catppuccin"

    [theme.custom]
    accent = "${accents.blue.d}"
    panel_bg = "${base.b950}"
    surface_dim = "${base.black}"
    surface0 = "${base.b900}"
    surface1 = "${base.b850}"
    overlay0 = "${base.b700}"
    overlay1 = "${base.b600}"
    text = "${base.b200}"
    subtext0 = "${base.b500}"
    mauve = "${accents.purple.d}"
    green = "${accents.green.d}"
    yellow = "${accents.yellow.d}"
    red = "${accents.red.d}"
    blue = "${accents.blue.d}"
    teal = "${accents.cyan.d}"
    peach = "${accents.orange.d}"

    [ui.toast]
    delivery = "system"

    [ui]
    show_agent_labels_on_pane_borders = true
  '';
}
