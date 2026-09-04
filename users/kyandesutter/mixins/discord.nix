{ config, lib, pkgs, ... }:
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

  # Last.fm rich presence (moonbase id `lastFmRpc`), fetched and unpacked the
  # same way as moonlight-css above and for the same reason, and with the same
  # hash caveat: extensions-dist only publishes the current build.
  lastFmRpc = pkgs.stdenvNoCC.mkDerivation {
    pname = "moonlight-lastfmrpc";
    version = "1.0.1";
    src = pkgs.fetchurl {
      url = "https://moonlight-mod.github.io/extensions-dist/lastFmRpc.asar";
      hash = "sha256-LlloHDzx3vXOmGZQTnEye0zWBHjM3owoQutEu5VUUow=";
    };
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.asar ];
    installPhase = ''
      runHook preInstall
      asar extract $src $out
      runHook postInstall
    '';
  };

  # midnight-discord's colour module on its own. colors.css declares a
  # --bg/--text/--accent ladder and maps every Discord design token onto it,
  # which is the mapping layer a wallpaper palette needs; the rest of the theme
  # (main.css: panel gaps, rounded borders, Figtree) stays out, so Discord keeps
  # its stock layout. Pinned by rev because the module only exists in the repo,
  # not in the built midnight.css the theme publishes.
  #
  # Listed in `paths` ahead of the matugen output: moonlight-css loads local
  # files in the order given and appends one style element each, so the later
  # file wins between two :root blocks. On its own colors.css is inert, since
  # its token block sits behind `@container root style(--colors: on)` and the
  # named container is declared in main.css; the matugen template sets it.
  midnightColors = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/refact0r/midnight-discord/85dd67148cbbbfa027cb091e41a479a16ab16a65/src/colors.css";
    hash = "sha256-Q8mVcMCeAMv+6sDf5ZX7YVtA/YWdSFxwGZrCLSf5C1o=";
  };

  # Rendered by matugen's [templates.discord] block (mixins/dms.nix) on every
  # wallpaper pick and light/dark flip. Linux only: there is no matugen on the
  # mac, where Discord follows the system appearance on its own.
  matugenCss = "${config.home.homeDirectory}/.config/moonlight-mod/matugen.css";

  # moonlight reads its config from Electron's appData dir, named after the
  # client's release channel in resources/build_info.json (`stable` here).
  moonlightConfigFile =
    (if pkgs.stdenv.hostPlatform.isDarwin then "Library/Application Support" else ".config")
    + "/moonlight-mod/stable.json";

  # moonlight rewrites this file on every launch and whenever moonbase changes a
  # setting. Activation lands it 0400, so those writes fail (moonlight logs
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
        # URLs are fetched in the node process (not @import'd in the renderer,
        # so Discord's CSP never sees them) and always load after local files.
        config.paths = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          "${midnightColors}"
          matugenCss
        ]
        ++ [
          "https://allpurposemat.codeberg.page/Disblock-Origin/DisblockOrigin.theme.css"
        ];
      };

      # Reads the now-playing track from the Last.fm API and dispatches it as a
      # local activity, so it shows up next to Discord's own Spotify presence.
      # Unset settings fall back to the manifest defaults, which already hide
      # the presence while Spotify is playing.
      lastFmRpc = {
        enabled = true;
        config = {
          username = "FormalSnake";
          # Substituted at activation from the agenix secret; see below.
          apiKey = "@lastfmApiKey@";
          # The default is the literal string "some music".
          nameFormat = "artist-first";
        };
      };
    };
    repositories = [ "https://moonlight-mod.github.io/extensions-dist/repo.json" ];
    # Loaded as a developer extension: the normal extensions dir is moonbase's
    # to write, this one is ours.
    devSearchPaths = [
      "${moonlightCss}"
      "${lastFmRpc}"
    ];
  };

  moonlightConfigTemplate =
    (pkgs.formats.json { }).generate "moonlight-stable.json"
      moonlightConfig;
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

  # Not a home.file: the Last.fm API key is agenix-encrypted, and a home.file
  # would bake it into a world-readable store path. Activation substitutes it
  # into the generated template instead, then drops write permission so the
  # config stays as read-only to moonlight as the old store symlink was.
  #
  # agenix mounts /run/agenix from a launchd daemon on darwin rather than during
  # activation, so the switch that first adds a secret can get here before it
  # exists. That renders an empty key and the next switch fixes it, which is why
  # the missing case warns instead of failing the activation.
  home.activation.moonlightConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    key=""
    if [ -r /run/agenix/lastfm-api-key ]; then
      key=$(tr -d '\n' < /run/agenix/lastfm-api-key)
    else
      warnEcho "moonlight: /run/agenix/lastfm-api-key is missing, Last.fm presence will not authenticate"
    fi
    conf="${config.home.homeDirectory}/${moonlightConfigFile}"
    mkdir -p "$(dirname "$conf")"
    rm -f "$conf"
    (
      umask 077
      ${lib.getExe pkgs.gnused} "s|@lastfmApiKey@|$key|" ${moonlightConfigTemplate} > "$conf"
    )
    chmod 400 "$conf"
  '';

  # moonlight-css only watches paths that exist when it loads: one it cannot
  # stat is logged and dropped, and nothing re-checks it until the config is
  # saved again. matugen doesn't write the file until the first re-theme, so
  # seed an empty one to close that window on a fresh install.
  home.activation.moonlightMatugenCss =
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux
      (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -e "${matugenCss}" ]; then
          mkdir -p "$(dirname "${matugenCss}")"
          : > "${matugenCss}"
        fi
      '');
}
