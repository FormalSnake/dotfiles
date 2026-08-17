{ config, lib, ... }:
let
  cfg = config.kyan.profiles.desktop;
in
{
  options.kyan.profiles.desktop.enable = lib.mkEnableOption "macOS desktop profile";

  config = lib.mkIf cfg.enable {
    # Currently empty: unlike the NixOS counterpart (which gates the whole
    # Hyprland stack), every darwin mixin is always-on — this flag exists for
    # host-wiring symmetry and as the hook if darwin mixins ever grow gates.
  };
}
