{ config, pkgs, lib, inputs, ... }:
let
  # Pull the real catppuccin palette (the same flake input that themes
  # ghostty/neovim/herdr) and key into whichever flavor is active globally.
  # palette.json is `<flavor>.colors.<name>.hex` ("#rrggbb"); jankyborders wants
  # 0xAARRGGBB, so strip the `#` and prepend an opaque alpha.
  palette =
    (lib.importJSON
      "${inputs.catppuccin.packages.${pkgs.stdenv.hostPlatform.system}.palette}/palette.json")
    .${config.catppuccin.flavor}.colors;

  borderColor = c: "0xff" + lib.removePrefix "#" c.hex;

  # Focused window gets the catppuccin accent; everything else a muted surface.
  # Like herdr, this statically follows catppuccin.flavor — jankyborders has no
  # light/dark "auto" mode, so it doesn't swap on macOS appearance changes the
  # way ghostty/neovim do.
  activeColor = borderColor palette.mauve;
  inactiveColor = borderColor palette.surface0;
in
{
  # jankyborders — draws a colored border around the focused window, pairing
  # with aerospace's gapped tiling. Configured purely via CLI args on the
  # launchd agent (the same approach nix-darwin's own module takes), which
  # sidesteps the executable ~/.config/borders/bordersrc dance entirely.
  home.packages = [ pkgs.jankyborders ];

  launchd.agents.borders = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.jankyborders}/bin/borders"
        "style=round"
        "width=6.0"
        "hidpi=on"
        "active_color=${activeColor}"
        "inactive_color=${inactiveColor}"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/borders.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/borders.log";
    };
  };
}
