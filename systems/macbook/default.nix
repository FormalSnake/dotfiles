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

  # Self-hosted music: Navidrome serves the library on the SD card at
  # /Volumes/Music, Lidarr + slskd + Soularr fill it. Reachable from the iPhone
  # over Tailscale only.
  kyan.music.enable = true;

  # Office Discord bot: watches the Minecraft server and answers /status. Runs
  # as a container on the local Docker, source pinned in the mixin.
  kyan.officeDcBot.enable = true;

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
    "FISHER"
    "Always Mirin"
    "Asentrix"
    "Big Shaq"
    "DJ Unzensiert"
    "Diplo"
    "Douvelle19"
    "HARDSTYLE CVNT"
    "High Beam"
    "Hutcher"
    "In Parallel"
    "Inlie"
    "Jazzy"
    "Jeff Germita"
    "L.P. Rhythm"
    "Lenge"
    "MC WM"
    "Magic Flowers"
    "Marcus Cito"
    "Oppidan"
    "PureMiND"
    "Pìjus"
    "RomancePlanet"
    "STAKILLAZ"
    "Soul Wun"
    "Supershy"
    "ThomX"
    "latex fruit"
    "nimino"
    "ovg!"
    "velours"
    "Eliza Rose"
    "ACRAZE"
    "Adam Port"
    "Biscits"
    "Cheeks"
    "DJ CARPET"
    "DJ Katch"
    "Dentist"
    "GEE LEE"
    "Gravagerz"
    "HUGEL"
    "Haus Geek"
    "Hotel Ugly"
    "Joost"
    "KTmelodies"
    "KiLLOWEN"
    "LOSTBOYJAY"
    "LSPLASH"
    "Lance Savali"
    "Lawrence Hart"
    "Matroda"
    "Mau P"
    "Mikeeysmind"
    "Montêtna"
    "Noxygen"
    "Obskür"
    "Oden & Fatzo"
    "PXRKX"
    "Rad&Co"
    "Rampa"
    "Sohaoying"
    "Soluna"
    "Sports"
    "Texture"
    "Thereal King Jay"
    "Twin Diplomacy"
    "Uglyburger0"
    "VXLLAIN"
    "Why U So"
    "Woodcamp"
    "all things break"
    "belac"
    "boggio"
    "d4vd"
    "gabester"
    "prod. DTM"
    "wev"
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

  # TouchID sudo disabled: fall back to password for sudo (TouchID isn't usable
  # over SSH/mosh on the remote work server anyway).
  security.pam.services.sudo_local.touchIdAuth = false;
}
