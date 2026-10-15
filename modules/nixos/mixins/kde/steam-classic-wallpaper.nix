# Valve's own Steam cog wallpaper (from the SteamOS 1.0 archive), recoloured
# from Steam blue to the VGUI olive of ./steamed-theme.nix.
{ runCommand, fetchurl, dpkg, imagemagick }:
runCommand "steam-classic-wallpaper"
  {
    nativeBuildInputs = [ dpkg imagemagick ];
    src = fetchurl {
      url = "https://repo.steampowered.com/steamos/pool/main/v/valve-wallpapers/valve-wallpapers_0.7%2Bbsos2_all.deb";
      hash = "sha256-D8riXwbAfDAEkXZEs085OD6Wln5WVTPvn3CxCL2o6qM=";
    };
  }
  ''
    dpkg-deb -x $src deb
    mkdir -p $out/share/wallpapers
    magick deb/usr/share/backgrounds/cog.png -colorspace Gray -auto-level \
      +level-colors "#1f2419","#5a6a50" $out/share/wallpapers/steam-classic.png
  ''
