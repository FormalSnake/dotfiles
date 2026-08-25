{ pkgs, lib, config, osConfig, ... }:
let
  # Widevine DRM. Helium (ungoogled-chromium, chromium 149) is *compiled* with
  # Widevine support (the binary carries CdmAdapter / com.widevine.alpha) but the
  # upstream tarball ships no proprietary CDM, so DRM sites (Netflix, Spotify, …)
  # won't play. pkgs.widevine-cdm provides Chrome's CDM in the layout Chromium
  # expects (a dir with manifest.json + _platform_specific/linux_x64/libwidevinecdm.so).
  cdmDir = "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm";

  # Chromium can locate the CDM two ways; Helium is built for the *second* one, so
  # the hint file below is what actually enables playback. We provide both anyway:
  # they point at the same CDM, so there is no version skew.
  #
  #  1. Bundled (DIR_BUNDLED_WIDEVINE_CDM): a `WidevineCdm/` dir next to the
  #     binary. Honored only under the bundle_widevine_cdm build flag, which Helium
  #     does NOT set (the symlinked CDM is silently ignored). Kept as a no-cost
  #     fallback in case a future build flips the flag.
  #  2. Component hint (FILE_COMPONENT_WIDEVINE_CDM_HINT): Helium is built with
  #     enable_widevine_cdm_component, so on first run it creates an empty
  #     ~/.config/net.imput.helium/WidevineCdm/ and, at CDM registration, reads a
  #     hint file there to find the CDM. Normally the component updater writes it,
  #     but Helium runs with --disable-component-update, so it stays empty. We
  #     write the hint ourselves (see home.file below).
  #
  # Symlinking the *directory* keeps the .so a real file in another store path, so
  # autoPatchelfHook (find -type f, no -L) and the LD_LIBRARY_PATH wrapper leave it
  # untouched: it is already patched upstream. Linux Widevine is L3 → up to 720p
  # on Netflix (the platform cap).
  heliumBase = pkgs.helium.overrideAttrs (old: {
    # Helium's "Use GTK" appearance option dlopens libgtk at runtime (the binary
    # carries the loader strings libgtk-4.so.1 then libgtk-3.so.0). The upstream
    # build ships no GTK, so the dlopen fails and the toggle silently falls back
    # to the Classic theme. runtimeDependencies (not buildInputs: GTK is
    # dlopen'd, not DT_NEEDED, so autoPatchelfHook won't add it otherwise) puts
    # libgtk-3.so.0 on the rpath. GTK3 not 4: Chromium defaults to the GTK3
    # backend (GTK4 is opt-in behind --gtk-version=4 and still incomplete).
    runtimeDependencies = (old.runtimeDependencies or [ ]) ++ [ pkgs.gtk3 ];
    postInstall = (old.postInstall or "") + ''
      ln -s ${cdmDir} $out/opt/helium/WidevineCdm
    '';
  });

  helium = heliumBase;

  # Helium's user-data dir (cf. its Crash Reports path). The whole dir, all
  # three profiles included, live-syncs between the two laptops as the
  # syncthing folder `helium-profile` (modules/nixos/mixins/syncthing.nix).
  userDataDir = "${config.home.homeDirectory}/.config/net.imput.helium";

  # Takeover guard peer: the other Linux laptop in the syncthing mesh. The mac
  # only keeps a hub copy of the folder; its own Helium is not part of this.
  host = osConfig.networking.hostName;
  peer = if host == "g815" then "e1504g" else "g815";
  myDeviceId = osConfig.services.syncthing.settings.devices.${host}.id or "";

  # Takeover guard: the profile live-syncs under a one-browser-at-a-time model,
  # so launching here must first cleanly quit the peer's instance and let its
  # final state replicate before Helium opens the databases. The guard shadows
  # the real `helium` via hiPrio (the desktop entry runs `helium %U`, Mod+B
  # and the CLI resolve it through the profile bin), so every launch path
  # passes through it. Every failure mode (peer off, ssh broken, syncthing
  # REST down) degrades to launching immediately; the guard may never strand
  # the browser.
  #
  # --password-store=basic: Chromium encrypts cookies with a key from the
  # desktop keyring, which differs per machine, so a synced Cookies file would
  # be unreadable on the peer and each side's logins would wipe the other's.
  # The basic store uses a fixed key, so cookies (logins) follow the profile.
  # Firefox never encrypted them at all, so this matches what Zen synced.
  #
  # Fast path first: if the browser process already runs locally, this
  # invocation is just a new-window/URL request (Chromium's singleton hands it
  # over) and the peer was already dealt with when that instance started.
  #
  # Every helium process (browser, gpu, renderers) has comm "helium", as does
  # this guard while it runs, so the browser process is found by cmdline: the
  # real binary path without a --type= flag (child processes all carry one).
  guard = lib.hiPrio (
    pkgs.writeShellScriptBin "helium" ''
      real=${helium}/bin/helium
      export PATH=${
        lib.makeBinPath [ pkgs.procps pkgs.coreutils pkgs.curl pkgs.jq pkgs.gnused pkgs.openssh ]
      }:$PATH

      browser_pids() {
        for p in $(pgrep -x helium); do
          c=$(tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null) || continue
          case "$c" in
            *opt/helium/helium*--type=*) ;;
            *opt/helium/helium*) echo "$p" ;;
          esac
        done
      }

      if [ -n "$(browser_pids)" ]; then
        exec "$real" --password-store=basic "$@"
      fi

      # Remote side runs under /bin/sh (the login shell is fish, not POSIX)
      # with absolute tool paths (non-interactive PATH is minimal). It quits
      # the peer's browser process (SIGTERM is a clean Chromium shutdown:
      # session saved, databases closed), waits for it to exit, forces a
      # folder rescan and waits until the peer reports this device 100% in
      # sync, the authoritative "everything I had has reached you" signal.
      # Prints "took" iff it actually quit something, so an idle/offline peer
      # costs only the ssh probe.
      took=$(ssh -o BatchMode=yes -o ConnectTimeout=2 ${peer} /bin/sh -s ${myDeviceId} <<'REMOTE' 2>/dev/null
      myid="$1"
      P=/run/current-system/sw/bin
      browser_pids() {
        for p in $($P/pgrep -x helium); do
          c=$($P/tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null) || continue
          case "$c" in
            *opt/helium/helium*--type=*) ;;
            *opt/helium/helium*) echo "$p" ;;
          esac
        done
      }
      pids=$(browser_pids)
      [ -n "$pids" ] || exit 0
      kill -TERM $pids 2>/dev/null || true
      i=0
      while [ -n "$(browser_pids)" ] && [ "$i" -lt 120 ]; do
        $P/sleep 0.25; i=$((i+1))
      done
      echo took
      key=$($P/sed -n 's/.*<apikey>\(.*\)<\/apikey>.*/\1/p' "$HOME/.config/syncthing/config.xml" | $P/head -n1)
      [ -n "$key" ] && [ -n "$myid" ] || exit 0
      $P/curl -s -m 5 -X POST -H "X-API-Key: $key" \
        "http://127.0.0.1:8384/rest/db/scan?folder=helium-profile" >/dev/null 2>&1 || exit 0
      i=0
      while [ "$i" -lt 40 ]; do
        c=$($P/curl -s -m 2 -H "X-API-Key: $key" \
          "http://127.0.0.1:8384/rest/db/completion?folder=helium-profile&device=$myid" \
          | $P/grep -o '"completion"[: ]*[0-9.]*' | $P/grep -o '[0-9.]*$')
        case "$c" in 100|100.0*) break ;; esac
        $P/sleep 0.5; i=$((i+1))
      done
      exit 0
      REMOTE
      ) || took=""

      # After a takeover, settle locally too: the folder must have nothing
      # left to pull for two consecutive polls (right after the peer's rescan
      # a single 0 can be a not-yet-announced index). Capped, then launch
      # regardless: worst case equals a manual "quit there, open here".
      if [ -n "$took" ]; then
        key=$(sed -n 's/.*<apikey>\(.*\)<\/apikey>.*/\1/p' "$HOME/.config/syncthing/config.xml" | head -n1)
        if [ -n "$key" ]; then
          ok=0 i=0
          while [ "$i" -lt 20 ]; do
            if curl -s -m 2 -H "X-API-Key: $key" \
              "http://127.0.0.1:8384/rest/db/status?folder=helium-profile" \
              | jq -e '.needTotalItems == 0 and .state == "idle"' >/dev/null 2>&1; then
              ok=$((ok+1))
              [ "$ok" -ge 2 ] && break
            else
              ok=0
            fi
            sleep 0.5; i=$((i+1))
          done
        fi
      fi
      exec "$real" --password-store=basic "$@"
    ''
  );

  # Kopuz hosts Spotify's Web Playback SDK in a browser tab and picks one by
  # binary name on PATH (chromium, chromium-browser, google-chrome, brave,
  # microsoft-edge, vivaldi). Firefox is excluded upstream because the SDK dies
  # in it. The SDK needs Widevine, which rules out a bare pkgs.chromium; Helium
  # is ungoogled-chromium with the CDM above already wired up, so expose it
  # under the name Kopuz probes for instead of installing a second Chromium.
  # Through the guard, so a Kopuz-triggered cold start gets the same flags and
  # takeover as any other launch; a running Helium takes the URL over its
  # singleton and reuses the profile that carries the CDM hint file below.
  kopuzChromium = pkgs.runCommand "helium-chromium-alias" { } ''
    mkdir -p $out/bin
    ln -s ${guard}/bin/helium $out/bin/chromium
  '';
in
{
  # Helium browser. The overlay (inputs.helium.overlays.default) is applied at
  # the system level in modules/nixos/mixins/nix.nix, so pkgs.helium resolves.
  home.packages = [
    helium
    guard
    kopuzChromium
  ];

  # Widevine component hint file (path #2 above). A JSON dict whose "Path" points
  # at the dir holding manifest.json + _platform_specific/…. Chromium reads it via
  # FILE_COMPONENT_WIDEVINE_CDM_HINT = <user-data-dir>/WidevineCdm/<this file>.
  home.file.".config/net.imput.helium/WidevineCdm/latest-component-updated-widevine-cdm".text =
    builtins.toJSON { Path = cdmDir; };

  # Default browser: xdg-mime defaults (mimeApps.enable is set in
  # desktop-apps.nix) plus BROWSER. DMS/FormalShell read the default browser
  # through the xdg mime database, so this is also what makes them show Helium.
  xdg.mimeApps.defaultApplications = lib.genAttrs [
    "text/html"
    "application/xhtml+xml"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
    "x-scheme-handler/about"
    "x-scheme-handler/unknown"
  ] (_: [ "helium.desktop" ]);
  home.sessionVariables.BROWSER = "helium";

  # Syncthing ignore rules for the helium-profile folder, written as a real
  # file (syncthing reads it from inside the folder; a home.file symlink would
  # be a per-host store path). Kept out of sync: the singleton lock trio and
  # LevelDB locks (`(?d)`: syncthing may delete them to complete a sync),
  # every cache Chromium regenerates, crash/metrics state, the home-manager
  # Widevine hint (per-host store path), and 1Password's per-machine storage
  # (its chrome.storage.local and IndexedDB, keyed by the extension id; it
  # pairs with the local desktop app and re-pairing on every takeover is what
  # the Zen setup had to avoid too). `*` never matches `/`, so `/*/…` is
  # exactly the profile-dir level. Bare names (LOCK, LOG) match at any depth.
  # Safe to write while Helium runs: it is syncthing's file, not Helium's.
  home.activation.heliumStignore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${lib.escapeShellArg userDataDir}
    cat > ${lib.escapeShellArg "${userDataDir}/.stignore"} <<'EOF'
    (?d)/SingletonLock
    (?d)/SingletonSocket
    (?d)/SingletonCookie
    (?d)/lockfile
    (?d)LOCK
    LOG
    LOG.old
    /BrowserMetrics*
    /Crash Reports
    /Crashpad
    /Local Traces
    /GPUPersistentCache
    /GrShaderCache
    /GraphiteDawnCache
    /ShaderCache
    /component_crx_cache
    /segmentation_platform
    /Webstore Downloads
    /WidevineCdm
    /*/Cache
    /*/Code Cache
    /*/GPUCache
    /*/DawnGraphiteCache
    /*/DawnWebGPUCache
    /*/Service Worker/CacheStorage
    /*/Service Worker/ScriptCache
    /*/blob_storage
    /*/Shared Dictionary
    /*/optimization_guide_*
    /*/Local Extension Settings/aeblfdkhhhdcdjpifhhbdiojplfjncoa
    /*/IndexedDB/chrome-extension_aeblfdkhhhdcdjpifhhbdiojplfjncoa_*
    EOF
  '';
}
