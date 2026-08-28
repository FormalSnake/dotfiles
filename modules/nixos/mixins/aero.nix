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

    # Win7 boot splash on every boot, Hyprland ones included. `quiet` keeps the
    # kernel log off the splash; the systemd initrd shows it from the first
    # stage rather than only after the root mount.
    boot.plymouth.enable = true;
    boot.initrd.systemd.enable = true;
    boot.kernelParams = [ "quiet" ];

    programs.aeroshell = {
      enable = true;
      fonts.segoe.enable = true;
      polkit.enable = true;
      aerothemeplasma = {
        enable = true;
        # The greeter stays qylock's sword (mixins/hyprland.nix): this sets
        # services.displayManager.sddm.theme too and the two would collide.
        sddm.enable = false;
        plymouth.enable = true;
      };
    };
  };
}
