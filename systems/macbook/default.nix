{ self, ... }:
{
  imports = [
    ./homebrew.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  system = {
    primaryUser = "kyandesutter";
    stateVersion = 6;
  };

  kyan.profiles.desktop.enable = true;

  users.users.kyandesutter = {
    name = "kyandesutter";
    home = "/Users/kyandesutter";
  };

  home-manager.users.kyandesutter = {
    imports = [
      self.homeModules.kyandesutter
      self.homeModules.kyandesutter-darwin
    ];
  };

  # TouchID sudo disabled — fall back to password for sudo (TouchID isn't usable
  # over SSH/mosh on the remote work server anyway).
  security.pam.services.sudo_local.touchIdAuth = false;
}
