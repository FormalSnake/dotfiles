{ config, lib, inputs, ... }:
let
  cfg = config.kyan.desktop.aero;
in
{
  imports = [ inputs.aerothemeplasma-nix.nixosModules.aerothemeplasma-nix ];

  options.kyan.desktop.aero.enable = lib.mkEnableOption "AeroThemePlasma (Windows 7 rice on Plasma 6) as a second SDDM session";

  config = lib.mkIf cfg.enable {
    services.desktopManager.plasma6.enable = true;

    # plasma6 mkDefaults the SDDM default session to plasma; Hyprland stays
    # the default and Aero is picked from the greeter's session list.
    services.displayManager.defaultSession = "hyprland-uwsm";

    # No kmail/kontact stack, plasma6 mkDefaults it on.
    programs.kde-pim.enable = false;

    programs.aeroshell = {
      enable = true;
      fonts.segoe.enable = true;
      polkit.enable = true;
      aerothemeplasma = {
        enable = true;
        # The greeter stays qylock's sword (mixins/hyprland.nix): this sets
        # services.displayManager.sddm.theme too and the two would collide.
        sddm.enable = false;
        # Global boot splash; a Win7 splash on Hyprland boots is not wanted.
        plymouth.enable = false;
      };
    };
  };
}
