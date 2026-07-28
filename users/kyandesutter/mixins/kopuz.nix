{ inputs, pkgs, ... }:
let
  kopuz = inputs.kopuz.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # On darwin the upstream package installs the bundle as $out/bin/kopuz.app
  # (with $out/bin/kopuz symlinked at the Mach-O inside it), so mac-app-util —
  # which only looks at $out/Applications — never sees it and Kopuz stays
  # invisible to Spotlight, Launchpad and the Dock. A separate symlink-only
  # derivation puts the bundle where mac-app-util looks without touching
  # kopuz's own derivation hash, which would cost us the cachix hit and a full
  # Rust build.
  macApp = pkgs.runCommand "kopuz-app" { } ''
    mkdir -p $out/Applications
    ln -s ${kopuz}/bin/kopuz.app $out/Applications/Kopuz.app
  '';
in
{
  # Kopuz — music player (local library, Jellyfin/Subsonic/Spotify backends).
  # Built by the upstream flake and fetched from kopuz.cachix.org; the
  # substituter is configured per platform in modules/{nixos/mixins/nix.nix,
  # darwin/mixins/determinate.nix}.
  home.packages = [ kopuz ] ++ pkgs.lib.optional pkgs.stdenv.isDarwin macApp;
}
