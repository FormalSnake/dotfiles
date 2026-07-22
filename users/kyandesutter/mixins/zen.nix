{ inputs, config, pkgs, lib, ... }:
let
  flexoki = import ./flexoki/palette.nix;

  # zen-wabi (github.com/parazeeknova/zen-wabi, vendored in ../zen-wabi/):
  # matugen-driven live theming for Zen. The CSS templates carry literal
  # first-paint colours in :root that the wabi bridge clobbers at runtime with
  # the wallpaper palette, so per the repo's theming model the baked-in values
  # are the static Flexoki dark fallback. Placeholder names are wabi's, not
  # matugen's — rendered here at eval time, not by matugen.
  renderWabi =
    src:
    builtins.replaceStrings
      [ "{{bg}}" "{{bg_dark}}" "{{bg_light}}" "{{fg}}" "{{fg_light}}" "{{accent}}" "{{secondary}}" "{{tertiary}}" ]
      [
        flexoki.base.black
        flexoki.base.b950
        flexoki.base.b900
        flexoki.base.b200
        flexoki.base.b500
        flexoki.accents.blue.d
        flexoki.accents.cyan.d
        flexoki.accents.purple.d
      ]
      (builtins.readFile src);

  profileChrome = "${config.programs.zen-browser.profilesPath}/default/chrome";

  # Vanilla Zen theme-store UUIDs, used both by sine.mods below and by the
  # repair fragment that pins each mod to the vanilla store layout.
  modUuids = [
    "bc25808c-a012-4c0d-ad9a-aa86be616019" # Sleek Border
    "a6335949-4465-4b71-926c-4a52d34bc9c0" # Better Find Bar
    "ae051a40-3e3a-429a-a6f4-199a28b18a75" # Only Reset On Hover
    "72f8f48d-86b9-4487-acea-eb4977b18f21" # Better CtrlTab Panel
    "906c6915-5677-48ff-9bfc-096a02a72379" # Floating Status Bar
    "c6813222-6571-4ba6-8faf-58f3343324f6" # Disable Rounded Corners
    "81fcd6b3-f014-4796-988f-6c3cb3874db8" # Zen Context Menu
    "599a1599-e6ab-4749-ab22-de533860de2c" # Pimp your PiP
  ];

  # Helium's extension set, mapped to the Firefox (AMO) equivalents, keyed by
  # addon GUID -> AMO slug. Three Helium extensions have no Firefox port and
  # are covered natively instead: GoFullPage (Firefox ships full-page
  # screenshots), SuperPiP (native PiP + the Pimp your PiP mod below), and
  # Playwriter (CDP bridge, Chromium-only by design). Dark Reader, DeArrow and
  # Equicord Web were dropped by choice in the move.
  extensions = {
    "{d634138d-c276-4fc8-924b-40a0ea21d284}" = "1password-x-password-manager";
    "@react-devtools" = "react-devtools";
    "{a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad}" = "refined-github-";
    "enhancerforyoutube@maximerf.addons.mozilla.org" = "enhancer-for-youtube";
    "extension@corne.rs" = "lisse";
    "{e7b84430-dae5-41e6-bb6f-9d01b02c4347}" = "elden-email";
  };
in
{
  # Zen browser (Firefox fork) via the community flake's home-manager module.
  imports = [ inputs.zen-browser.homeModules.beta ];

  # GPU: deliberately NOT pinned to the iGPU (contrast helium.nix). Firefox
  # follows the compositor's dmabuf-feedback device, so Zen renders on whatever
  # GPU niri renders on — iGPU normally, dGPU when docked — and a relog re-picks
  # it (Zen restarts with the session, so the gpu-relog-prompt flow also releases
  # a dGPU fd held from before an undock). The Chromium dmabuf-import bug that
  # forced lib/chromium-igpu.nix is ANGLE-specific and doesn't apply here.
  # VA-API likewise auto-selects its driver from the active render node, so no
  # LIBVA_DRIVER_NAME.
  programs.zen-browser = {
    enable = true;

    # xdg-mime defaults (http/https/text/html/…) + BROWSER=zen-beta. DMS reads
    # the default browser through the xdg mime database, so this is also what
    # makes it show Zen. helium.nix no longer sets BROWSER.
    setAsDefaultBrowser = true;

    policies = {
      ExtensionSettings = builtins.mapAttrs (_: slug: {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
        installation_mode = "force_installed";
      }) extensions;

      # 1Password owns passwords — kill the built-in manager (no save prompts,
      # no autofill, no about:logins nagging).
      PasswordManagerEnabled = false;
      OfferToSaveLogins = false;
    };

    profiles.default = {
      settings = {
        # Hardware video decode — off by default in Firefox on Linux.
        "media.ffmpeg.vaapi.enabled" = true;

        # Borderless web frame (the Arc look): collapse the 8px gap Zen keeps
        # between the webview, sidebar and window edges, and zero the webview
        # corner radius (-1 default = "auto"; the Disable Rounded Corners mod
        # only flattens the chrome, not this).
        "zen.theme.content-element-separation" = 0;
        "zen.theme.border-radius" = 0;

        # wabi prerequisites (vendored user.js.template): load
        # userChrome/userContent.css (Zen defaults this off since 1.14), and
        # Browser Toolbox access for debugging the bridge.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "devtools.chrome.enabled" = true;
        "devtools.debugger.remote-enabled" = true;
        "userChromeJS.experimental.enabled" = true;

        # The wabi bridge is a local (non-store) Sine script mod; Sine refuses
        # JS from non-store mods unless this is set.
        "sine.allow-unsafe-js" = true;

        # Sine's auto-updater replaces nix-installed mods with Sine-store repo
        # layouts (no root theme.json/chrome.css), silently unregistering them
        # — observed 2026-07-22 with Better CtrlTab / Zen Context Menu /
        # Floating Status Bar. Mod state is nix-managed; updates arrive via the
        # repair fragment below, never at runtime.
        "sine.auto-updates" = false;

        # Firefox only shows the Ctrl+Tab MRU panel (the thing the Better
        # CtrlTab Panel mod styles) with this on.
        "browser.ctrlTab.sortByRecentlyUsed" = true;

        # Matugen themes the browser chrome ONLY. Zen Boosts is the per-domain
        # tint machinery the wabi bridge uses to recolor websites — off kills
        # both Zen's own tinting and the bridge's universal-boost sync (its
        # boosts manager never loads). The workspace-gradient sync is separate
        # and unaffected.
        "zen.boosts.enabled" = false;
      };

      # Sine (fx-autoconfig based mod loader). Enabling it makes the flake patch
      # the zen package with the autoconfig bootstrap (config.js +
      # defaults/pref) and install the bootloader into chrome/utils — the same
      # loader the wabi bridge below rides on. Mods resolve from the Sine store
      # first, falling back to the vanilla Zen theme store by UUID.
      sine.enable = true;
      sine.mods = modUuids;

      userChrome = renderWabi ../zen-wabi/userChrome.css.template;
      userContent = renderWabi ../zen-wabi/userContent.css.template;

      # Spaces. The two org spaces get their own containers (separate cookie
      # jars), so the personal Google account (default jar) and the
      # CanaryCoders workspace account never fight over google.com cookies.
      # NOTE: close Zen before a home-manager switch that changes spaces or
      # containers — the activation script needs exclusive access to the
      # session files.
      # Container colors are Firefox's fixed 8-colour enum (tab stripe/badge
      # only) — matugen can't drive them. The space *gradients* are left
      # undeclared on purpose: the wabi bridge injects the matugen accent
      # gradient into the active space on every palette change
      # (syncWorkspaceTheme), and a static theme here would just fight it.
      containers = {
        CanaryCoders = {
          color = "orange";
          icon = "briefcase";
          id = 2;
        };
        KangaCoders = {
          color = "green";
          icon = "briefcase";
          id = 3;
        };
      };

      # Icons come from Zen's built-in selectable set (what the space icon
      # picker stores): chrome/browser/skin/zen-icons/selectable/ in omni.ja.
      spacesForce = true; # exactly these three; also removes Zen's starter space
      spaces = {
        "Personal" = {
          id = "d5a017b0-2212-4298-83c0-f2e0ec65149a";
          position = 1000;
          icon = "chrome://browser/skin/zen-icons/selectable/star.svg";
          # One GitHub account across all three orgs — route every github URL
          # here so the login lives in a single (default) cookie jar instead of
          # three per-container sessions.
          routes."GitHub" = {
            reference = "github.com"; # matchType "contains"
          };
        };
        "CanaryCoders" = {
          id = "1bc90784-e304-4f00-a7e3-f9c5fed586b3";
          position = 2000;
          icon = "chrome://browser/skin/zen-icons/selectable/code.svg";
          container = 2;
          # Claude tabs always land in this space.
          routes."Claude" = {
            reference = "claude.ai"; # matchType "contains"
          };
        };
        "KangaCoders" = {
          id = "d581d21a-46ae-46a6-8f4b-a037833a0bae";
          position = 3000;
          icon = "chrome://browser/skin/zen-icons/selectable/rocket.svg";
          container = 3;
        };
      };
    };
  };

  # wabi's live-update chain: matugen (run by DMS, template registered in
  # dms.nix) renders the wallpaper palette to chrome/matugen-vars.json; the
  # bridge polls its mtime, mirrors the 8 colours into matugen.theme.* prefs,
  # sets --matugen-* vars inline on the chrome :root, and a JSWindowActor child
  # applies the same vars in every content process — colours flip live, no
  # restart.
  #
  # Loading: Sine's config.js only imports sine.sys.mjs, which executes
  # scripts LISTED IN sine-mods/mods.json — loose *.uc.js under chrome/JS are
  # never picked up (unlike stock fx-autoconfig, which wabi was written for).
  # So the bridge ships as a local Sine script mod, renamed to .sys.mjs: Sine
  # importESModule()s those exactly once into the shared module global — which
  # is also what lets MatugenParent see globalThis.__matugenBridge. The actor
  # modules stay under chrome/JS because their chrome://userscripts/ URIs map
  # there (bootloader chrome.manifest: `content userscripts ../JS/`).
  home.file = {
    "${profileChrome}/sine-mods/zen-wabi-bridge/matugen-bridge.sys.mjs".source =
      ../zen-wabi/matugen-bridge.uc.js;
    "${profileChrome}/JS/Matugen/MatugenChild.sys.mjs".source = ../zen-wabi/Matugen/MatugenChild.sys.mjs;
    "${profileChrome}/JS/Matugen/MatugenParent.sys.mjs".source = ../zen-wabi/Matugen/MatugenParent.sys.mjs;
  };

  # mods.json is runtime-mutable (Sine and the flake's sine fragment both
  # rewrite it), so the bridge's mod entry is injected idempotently via the
  # module's activation bus, after the flake's sine fragment (priority 100)
  # has ensured the file exists. No `origin` field -> not "store", hence the
  # sine.allow-unsafe-js pref above.
  programs.zen-browser.activationFragments.default = [
    # Syncthing ignore rules for the zen-profile folder (mixins/syncthing.nix,
    # NixOS-side): keep locks, crash/telemetry state and — the point — all of
    # 1Password's per-machine storage out of sync. 1Password's storage dir is
    # keyed by the profile's internal extension uuid (prefs.js,
    # extensions.webextensions.uuids), so it's resolved here at activation
    # time; on a fresh profile prefs.js doesn't exist yet and the line is
    # simply omitted (there is no 1Password state to leak yet either — the
    # next activation after first launch adds it). The `?` glob stands in for
    # the literal braces in the addon id: Syncthing's pattern language treats
    # braces specially, `?` matches any single character.
    {
      priority = 15;
      requiresLock = true;
      skipSubject = "syncthing stignore";
      text = ''
        profileDir="${config.programs.zen-browser.profilesPath}/default"
        mkdir -p "$profileDir"
        onePassUuid=""
        if [ -f "$profileDir/prefs.js" ]; then
          onePassUuid="$(sed -n 's/^user_pref("extensions\.webextensions\.uuids", "\(.*\)");$/\1/p' "$profileDir/prefs.js" \
            | sed 's/\\"/"/g' \
            | ${lib.getExe pkgs.jq} -r '."{d634138d-c276-4fc8-924b-40a0ea21d284}" // empty' || true)"
        fi
        {
          echo "(?d)lock"
          echo "(?d).parentlock"
          echo "(?d)/crashes"
          echo "(?d)/minidumps"
          echo "/datareporting"
          echo "/saved-telemetry-pings"
          echo "/browser-extension-data/?d634138d-c276-4fc8-924b-40a0ea21d284?"
          if [ -n "$onePassUuid" ]; then
            echo "/storage/default/moz-extension+++$onePassUuid*"
          fi
        } > "$profileDir/.stignore"
      '';
    }
    # Mod repair: pin every declared mod to the VANILLA zen theme-store layout
    # (theme.json + chrome.css at the dir root). Two failure modes need this:
    # the flake's sine fragment prefers the Sine store, whose zips for several
    # of these mods are repo dumps without a root theme.json — it then writes
    # no mods.json entry, so the mod is present but never styled; and Sine's
    # runtime updater used to rewrite installed dirs the same way (now off via
    # sine.auto-updates=false). A dir without theme.json is wiped and
    # refetched from the vanilla store; the mods.json entry is (re)written
    # every run with no-updates pinned. Runs before the flake's sine fragment
    # (priority 100), which then skips these dirs as already installed.
    {
      priority = 90;
      requiresLock = true;
      skipSubject = "mod repair";
      text = ''
        modsBase="${config.programs.zen-browser.profilesPath}/default/chrome/sine-mods"
        modsFile="$modsBase/mods.json"
        mkdir -p "$modsBase"
        [ -f "$modsFile" ] || echo '{}' > "$modsFile"
        rm -rf "$modsBase"/tmp-*
        for id in ${lib.concatStringsSep " " modUuids}; do
          modDir="$modsBase/$id"
          if [ ! -f "$modDir/theme.json" ]; then
            rm -rf "$modDir"
            mkdir -p "$modDir"
            storeUrl="https://raw.githubusercontent.com/zen-browser/theme-store/main/themes/$id"
            if ! ${lib.getExe pkgs.curl} -sfL "$storeUrl/theme.json" -o "$modDir/theme.json"; then
              echo "zen: failed to fetch mod $id from the vanilla theme store" >&2
              rm -rf "$modDir"
              continue
            fi
            for f in chrome.css preferences.json readme.md; do
              ${lib.getExe pkgs.curl} -sfL "$storeUrl/$f" -o "$modDir/$f" || rm -f "$modDir/$f"
            done
            $VERBOSE_ECHO "zen: reinstalled mod $id from the vanilla theme store"
          fi
          ${lib.getExe pkgs.jq} --arg id "$id" --argjson theme "$(cat "$modDir/theme.json")" '
            def to_local: if (. // "" | test("^https?://")) then (split("/") | last) else . end;
            .[$id] = ($theme
              | .id = $id | .enabled = true | ."no-updates" = true
              | .style = (if (.style | type) == "string" then { "chrome": (.style | to_local), "content": "" }
                  elif (.style | type) == "object" then { "chrome": ((.style.chrome // "") | to_local), "content": ((.style.content // "") | to_local) }
                  else { "chrome": "", "content": "" } end)
              | (if .preferences then .preferences = (.preferences | to_local) else . end)
              | (if .readme then .readme = (.readme | to_local) else . end))
          ' "$modsFile" > "$modsFile.tmp" && mv "$modsFile.tmp" "$modsFile"
        done
      '';
    }
    # Zen displays spaces in .spaces ARRAY order and ignores the position
    # field; the flake's session-store writer (priority 10) appends newly
    # declared spaces in nix attrset (= alphabetical) order. Re-sort the array
    # by our declared positions so Personal actually comes first.
    {
      priority = 20;
      requiresLock = true;
      skipSubject = "space order";
      text = ''
        sessionsFile="${config.programs.zen-browser.profilesPath}/default/zen-sessions.jsonlz4"
        if [ -f "$sessionsFile" ]; then
          spacesTmpJson="$(mktemp)"
          spacesTmpSorted="$(mktemp)"
          if ${lib.getExe pkgs.mozlz4a} -d "$sessionsFile" "$spacesTmpJson" \
            && ${lib.getExe pkgs.jq} '.spaces |= sort_by(.position // 0)' "$spacesTmpJson" > "$spacesTmpSorted" \
            && ${lib.getExe pkgs.mozlz4a} "$spacesTmpSorted" "$sessionsFile"; then
            $VERBOSE_ECHO "zen: sorted spaces by declared position"
          else
            echo "zen: failed to sort spaces by position" >&2
          fi
          rm -f "$spacesTmpJson" "$spacesTmpSorted"
        fi
      '';
    }
    {
      priority = 150;
      requiresLock = true;
      skipSubject = "wabi bridge mod";
      text = ''
        modsFile="${config.programs.zen-browser.profilesPath}/default/chrome/sine-mods/mods.json"
        mkdir -p "$(dirname "$modsFile")"
        [ -f "$modsFile" ] || echo '{}' > "$modsFile"
        ${lib.getExe pkgs.jq} '."zen-wabi-bridge" = {
          id: "zen-wabi-bridge",
          name: "zen-wabi matugen bridge",
          description: "Live matugen palette -> CSS vars (home-manager, mixins/zen.nix)",
          version: "1.7",
          "no-updates": true,
          enabled: true,
          scripts: { "matugen-bridge.sys.mjs": {} }
        }' "$modsFile" > "$modsFile.tmp" && mv "$modsFile.tmp" "$modsFile"
      '';
    }
  ];
}
