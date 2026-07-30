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

  # Rosetta-backed Linux builder VM, so this Mac can serve x86_64-linux builds
  # to the e1504g (and take its own Linux builds off the network). See
  # modules/darwin/mixins/rosetta-builder.nix for the bootstrap sequence — the
  # first switch after enabling needs an existing Linux builder.
  kyan.rosettaBuilder.enable = true;

  # Self-hosted music: Navidrome serves the library on the SD card at
  # /Volumes/Music, Lidarr + slskd + Soularr fill it. Reachable from the iPhone
  # over Tailscale only.
  kyan.music.enable = true;

  # Singles-led artists from the top of the scrobble history. Names must match
  # Lidarr's spelling, not MusicBrainz's or the scrobble export's.
  kyan.music.singlesArtists = [
    "Niko B"
    "Artemas"
    "nicopatty"
    "nuphory"
    "Swimming Paul"
    "Adi T"
    "CLOUDER"
    "Starjunk 95"
    "Adore"
    "Kavinsky"
  ];

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
