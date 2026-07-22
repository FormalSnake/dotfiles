{ inputs, config, ... }:
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

    policies.ExtensionSettings = builtins.mapAttrs (_: slug: {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
      installation_mode = "force_installed";
    }) extensions;

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
      };

      # Sine (fx-autoconfig based mod loader). Enabling it makes the flake patch
      # the zen package with the autoconfig bootstrap (config.js +
      # defaults/pref) and install the bootloader into chrome/utils — the same
      # loader the wabi bridge below rides on. Mods resolve from the Sine store
      # first, falling back to the vanilla Zen theme store by UUID.
      sine.enable = true;
      sine.mods = [
        "bc25808c-a012-4c0d-ad9a-aa86be616019" # Sleek Border
        "a6335949-4465-4b71-926c-4a52d34bc9c0" # Better Find Bar
        "c01d3e22-1cee-45c1-a25e-53c0f180eea8" # Ghost Tabs
        "ae051a40-3e3a-429a-a6f4-199a28b18a75" # Only Reset On Hover
        "72f8f48d-86b9-4487-acea-eb4977b18f21" # Better CtrlTab Panel
        "906c6915-5677-48ff-9bfc-096a02a72379" # Floating Status Bar
        "c6813222-6571-4ba6-8faf-58f3343324f6" # Disable Rounded Corners
        "ae7868dc-1fa1-469e-8b89-a5edf7ab1f24" # Load Bar
        "81fcd6b3-f014-4796-988f-6c3cb3874db8" # Zen Context Menu
        "599a1599-e6ab-4749-ab22-de533860de2c" # Pimp your PiP
      ];

      userChrome = renderWabi ../zen-wabi/userChrome.css.template;
      userContent = renderWabi ../zen-wabi/userContent.css.template;

      # Spaces. The two org spaces get their own containers (separate cookie
      # jars), so the personal Google account (default jar) and the
      # CanaryCoders workspace account never fight over google.com cookies.
      # NOTE: close Zen before a home-manager switch that changes spaces or
      # containers — the activation script needs exclusive access to the
      # session files.
      containers = {
        CanaryCoders = {
          color = "yellow";
          icon = "briefcase";
          id = 2;
        };
        KangaCoders = {
          color = "orange";
          icon = "briefcase";
          id = 3;
        };
      };

      spacesForce = true; # exactly these three; also removes Zen's starter space
      spaces = {
        "Personal" = {
          id = "d5a017b0-2212-4298-83c0-f2e0ec65149a";
          position = 1000;
          icon = "🏠";
        };
        "CanaryCoders" = {
          id = "1bc90784-e304-4f00-a7e3-f9c5fed586b3";
          position = 2000;
          icon = "🐤";
          container = 2;
          # Claude tabs always land in this space.
          routes."Claude" = {
            reference = "claude.ai"; # matchType "contains"
          };
        };
        "KangaCoders" = {
          id = "d581d21a-46ae-46a6-8f4b-a037833a0bae";
          position = 3000;
          icon = "🦘";
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
  # restart. Loaded from chrome/JS by the Sine bootloader, whose
  # chrome.manifest maps chrome://userscripts/ -> JS/ (the actor module URIs).
  home.file = {
    "${profileChrome}/JS/matugen-bridge.uc.js".source = ../zen-wabi/matugen-bridge.uc.js;
    "${profileChrome}/JS/Matugen/MatugenChild.sys.mjs".source = ../zen-wabi/Matugen/MatugenChild.sys.mjs;
    "${profileChrome}/JS/Matugen/MatugenParent.sys.mjs".source = ../zen-wabi/Matugen/MatugenParent.sys.mjs;
  };
}
