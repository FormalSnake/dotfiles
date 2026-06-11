{ inputs, ... }:
{
  # Create Spotlight-indexable aliases for GUI apps installed by Nix/Home Manager.
  # Home Manager's default app symlinks point into the Nix store, which Spotlight
  # often ignores; mac-app-util replaces them with proper macOS aliases under
  # ~/Applications/Home Manager Apps.
  imports = [ inputs.mac-app-util.darwinModules.default ];
}
