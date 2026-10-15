{ config, ... }:
let
  # External APFS SSD that stays plugged into the macbook. Its role is local,
  # personal data (media, archives): the internal disk is the dev server's.
  # CoreSimulator, DerivedData and gradle still sit on it only because the
  # internal disk has no room for them yet; they move back once the stale
  # build output under ~/Developer is gone. Every link below dangles while the drive is
  # unmounted.
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
  # storage-gc.sh deletes its target, so Xcode gets the path directly and
  # recreates the dir itself.
  targets.darwin.defaults."com.apple.dt.Xcode".IDECustomDerivedDataLocation =
    "${drive}/DerivedData";
}
