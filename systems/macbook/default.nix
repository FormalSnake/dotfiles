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

  # Office Discord bot: watches the Minecraft server and answers /status. Runs
  # as a container on the local Docker, source pinned in the mixin.
  kyan.officeDcBot.enable = false;

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

  # TouchID sudo disabled: fall back to password for sudo (TouchID isn't usable
  # over SSH/mosh on the remote work server anyway).
  security.pam.services.sudo_local.touchIdAuth = false;
}
