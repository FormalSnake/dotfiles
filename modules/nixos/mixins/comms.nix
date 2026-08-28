{ config, lib, pkgs, ... }:
{
  # Recording desktop apps. Rides on the desktop profile like the other
  # desktop-only mixins (phone-integration, online-accounts). The Discord client
  # moved to users/kyandesutter/mixins/discord.nix when Equibop was replaced by
  # moonlight, which is cross-platform and so lives in the home config.
  config = lib.mkIf config.kyan.desktop.enable {
    environment.systemPackages = [ pkgs.obs-studio ];
  };
}
