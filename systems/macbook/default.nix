{
  imports = [
    ./homebrew.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  system = {
    primaryUser = "kyandesutter";
    # nix-darwin state version — bump only when nix-darwin's release notes say to.
    stateVersion = 6;
  };

  kyan.profiles.desktop.enable = true;

  users.users.kyandesutter = {
    name = "kyandesutter";
    home = "/Users/kyandesutter";
  };

  # Allow Touch ID for sudo (declarative — nix-darwin writes /etc/pam.d/sudo_local)
  security.pam.services.sudo_local.touchIdAuth = true;
}
