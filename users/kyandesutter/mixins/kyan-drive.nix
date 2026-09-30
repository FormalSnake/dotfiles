{ config, ... }:
let
  # External APFS SSD that stays plugged into the macbook. It holds the bulky,
  # regenerable dirs and media that used to fill the internal SSD. Every link
  # below dangles while the drive is unmounted.
  drive = "/Volumes/Kyan Drive";
  link = sub: config.lib.file.mkOutOfStoreSymlink "${drive}/${sub}";
in
{
  home.file = {
    "Movies".source = link "Movies";
    ".gradle".source = link "gradle";
    # Simulator devices and their caches. Shut the simulators down and quit
    # CoreSimulatorService before moving this dir, or it recreates it mid-move.
    "Library/Developer/CoreSimulator".source = link "CoreSimulator";
  };

  # A symlinked DerivedData would turn into a dangling link the first time
  # mac-storage-gc.sh deletes its target, so Xcode gets the path directly and
  # recreates the dir itself.
  targets.darwin.defaults."com.apple.dt.Xcode".IDECustomDerivedDataLocation =
    "${drive}/DerivedData";
}
