{ lib, pkgs, ... }:
let
  # moonlight on the nightly channel. Nightly is just the tip of the mod's main
  # branch: https://moonlight-mod.github.io/moonlight/ref is the ref moonbase
  # would fetch, and dist.tar.gz next to it is the build. nixpkgs only packages
  # the tagged stable, so this re-points its src at that ref and rebuilds from
  # source rather than pulling the prebuilt tarball, which keeps nixpkgs'
  # disable_updates.patch on top (see below).
  #
  # To bump: `curl -s https://moonlight-mod.github.io/moonlight/ref` for the
  # rev, then let the build report the new hash. pnpmDeps re-derives itself from
  # the new src through finalAttrs and keeps the stable package's hash, which
  # holds only while pnpm-lock.yaml is untouched; a nightly that changes the
  # lockfile fails on that fixed-output hash and needs its own override.
  #
  # Updating in-app is not an option to preserve: moonbase writes an update into
  # its own dist dir, which here is the read-only store path. That is why
  # nixpkgs strips the updater, and the patch still applies at this rev.
  nightlyRev = "51d7751ea05ebc2e9e20ec8b52d5132fa30a8bf2";
  moonlightNightly = pkgs.moonlight.overrideAttrs (old: {
    version = "0-unstable-2026-08-27";
    src = pkgs.fetchFromGitHub {
      owner = "moonlight-mod";
      repo = "moonlight";
      rev = nightlyRev;
      hash = "sha256-ATxEm+29fBs4Ek7qo1hGhhzdPyJL7ELOIVA/FqjZA2M=";
    };
    env = old.env // {
      MOONLIGHT_BRANCH = "nightly";
      MOONLIGHT_VERSION = nightlyRev;
    };
  });

  # The CSS extension (moonbase id `moonlight-css`), as the prebuilt asar
  # moonbase would download, unpacked into the store. extensions-dist only
  # publishes the current build at a fixed URL and has no versioned artefact or
  # git tag to pin, so an upstream release breaks this hash; bump `version` and
  # take the hash the build reports.
  moonlightCss = pkgs.stdenvNoCC.mkDerivation {
    pname = "moonlight-css";
    version = "2.0.7";
    src = pkgs.fetchurl {
      url = "https://moonlight-mod.github.io/extensions-dist/moonlight-css.asar";
      hash = "sha256-0OaOG2OY5ODA4LzCBHMqhxb7I414aAWsP3N6l9kv7HQ=";
    };
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.asar ];
    installPhase = ''
      runHook preInstall
      asar extract $src $out
      runHook postInstall
    '';
  };

  # moonlight reads its config from Electron's appData dir, named after the
  # client's release channel in resources/build_info.json (`stable` here).
  moonlightConfigFile =
    (if pkgs.stdenv.hostPlatform.isDarwin then "Library/Application Support" else ".config")
    + "/moonlight-mod/stable.json";

  # moonlight rewrites this file on every launch and whenever moonbase changes a
  # setting. Pointing it at the store makes those writes fail (moonlight logs
  # "Failed to write config" and carries on with what it read), which is the
  # trade: extensions and their settings are declared here, and the moonbase UI
  # can no longer install or persist anything.
  moonlightConfig = {
    extensions = {
      # moonlight's own defaults, which only apply while no config file exists.
      moonbase = true;
      disableSentry = true;
      noTrack = true;
      noHideToken = true;

      "moonlight-css" = {
        enabled = true;
        config.paths = [
          "https://allpurposemat.codeberg.page/Disblock-Origin/DisblockOrigin.theme.css"
        ];
      };
    };
    repositories = [ "https://moonlight-mod.github.io/extensions-dist/repo.json" ];
    # Loaded as a developer extension: the normal extensions dir is moonbase's
    # to write, this one is ours.
    devSearchPaths = [ "${moonlightCss}" ];
  };
in
{
  # Discord with moonlight (https://moonlight-mod.github.io), the client mod.
  # nixpkgs builds the mod in and swaps resources/app.asar for a two-line loader
  # that requires moonlight's injector and hands it the real _app.asar, which is
  # the same patch the upstream installer applies imperatively. Doing it through
  # the package means a Discord update can't silently revert the injection.
  #
  # Replaced Equibop on the Linux hosts (2026-08-28); Equicord is gone with it,
  # and the wrapper asserts at most one client mod anyway. Worth knowing what
  # went with it: Vesktop's venmic is why Equibop could share desktop *audio* on
  # Wayland. Native Discord shares the screen through the xdg portal but has no
  # audio path, so screenshare here is video only.
  #
  # `--disable-features=WebRtcAllowInputVolumeAdjustment` is Linux-only: there
  # Chromium's WebRTC stack reaches into PipeWire and rides the *hardware* input
  # gain toward a loudness target, so the mic gradually gets quieter during a
  # call and the source slider visibly drops (the Razer was found pulled down to
  # 0.79). On macOS the same AGC stays inside Chromium's own pipeline and never
  # touches the OS slider.
  #
  # Discord is unfree; allowUnfree is global in modules/shared/mixins/nix.nix.
  home.packages = [
    (pkgs.discord.override (
      {
        withMoonlight = true;
        moonlight = moonlightNightly;
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        commandLineArgs = "--disable-features=WebRtcAllowInputVolumeAdjustment";
      }
    ))
  ];

  home.file.${moonlightConfigFile}.source =
    (pkgs.formats.json { }).generate "moonlight-stable.json"
      moonlightConfig;
}
