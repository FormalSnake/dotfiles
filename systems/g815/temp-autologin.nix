{ config, lib, ... }:
{
  # Temporary: SDDM logs straight into the Hyprland session so the reboot
  # cycle for the iGPU passthrough comes back without a password. Turn it off
  # once that cycle is done, and delete this file with it.
  options.kyan.tempAutologin.enable = lib.mkEnableOption "temporary SDDM autologin";

  config = lib.mkIf config.kyan.tempAutologin.enable {
    services.displayManager.autoLogin = {
      enable = true;
      user = "kyandesutter";
    };
    services.displayManager.defaultSession = "hyprland-uwsm";
  };
}
