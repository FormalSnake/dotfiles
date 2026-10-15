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

  # Rosetta-backed Linux builder VM: so this Mac can serve x86_64-linux builds
  # to the e1504g when the g815 is off, and build its own Linux closures far
  # faster than Determinate's single-job aarch64 builder.
  kyan.rosettaBuilder.enable = true;

  users.users.kyandesutter = {
    name = "kyandesutter";
    home = "/Users/kyandesutter";
  };

  home-manager.users.kyandesutter = {
    imports = [
      self.homeModules.kyandesutter
      self.homeModules.kyandesutter-darwin
    ];
    # SDK env and JDK for the Android Studio cask (mixins/android.nix).
    kyan.android.enable = true;
  };

  # TouchID sudo disabled: fall back to password for sudo (TouchID isn't usable
  # over SSH/mosh on the remote work server anyway).
  security.pam.services.sudo_local.touchIdAuth = false;
}
