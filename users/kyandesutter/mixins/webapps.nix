{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.webapps;

  # Engine: a Chromium browser launched in --app mode (one window, no browser
  # chrome). Chromium (unlike Tauri's WebKitGTK on Linux) passes Cloudflare bot
  # checks and renders well. Defaults to Helium — already this host's browser —
  # so all web apps share one browser binary instead of bundling a Chromium each.
  browserExe = lib.getExe cfg.browser;

  # Per-app Chromium profiles (persistent logins, isolated per app) and
  # activation-fetched favicons both live under here.
  dataRoot = "${config.home.homeDirectory}/.local/share/webapps";
  profileRoot = "${dataRoot}/profiles";
  iconDir = "${dataRoot}/icons";
  genericIcon = ./webapps-icons/generic.png;

  # --- pure helpers: URL → name/id/domain ------------------------------------
  domainOf = url:
    let noScheme = lib.last (lib.splitString "//" url);
    in lib.head (lib.splitString "/" noScheme);

  # domain → capitalized primary label (claude.ai → "Claude", www.x.co → "X")
  deriveName = url:
    let
      host = lib.removePrefix "www." (domainOf url);
      labels = lib.splitString "." host;
      n = lib.length labels;
      primary = if n >= 2 then lib.elemAt labels (n - 2) else lib.head labels;
      cap = s:
        lib.toUpper (lib.substring 0 1 s)
        + lib.substring 1 (builtins.stringLength s) s;
    in cap primary;

  slugify = name:
    lib.toLower (builtins.replaceStrings [ " " ] [ "-" ] name);

  # string | attrs → fully-populated attrs with defaults
  normalizeSite = raw:
    let
      s = if builtins.isString raw then { url = raw; } else raw;
      name = s.name or (deriveName s.url);
      id = s.id or (slugify name);
    in {
      inherit (s) url;
      inherit name id;
      description = s.description or "${name} web app";
      width = s.width or 1200;
      height = s.height or 800;
      # Accepted for interface stability across engines. Under Chromium --app on
      # a tiling WM (Hyprland) the window already has no title bar, so borderless
      # is the WM's concern; dark theming follows the site/system.
      darkMode = s.darkMode or true;
      borderless = s.borderless or true;
      # shareProfile = true → no dedicated --user-data-dir, so the app reuses the
      # browser's default profile (existing logins/session). Trade-off: the
      # window then runs inside the main browser process, so it inherits that
      # process's app_id/icon rather than showing as a separate app.
      shareProfile = s.shareProfile or false;
      icon = s.icon or null; # null → auto (activation-fetched favicon)
      domain = domainOf s.url;
    };

  # --- per-site launcher + desktop entry -------------------------------------
  buildWebApp = site:
    let
      # WM_CLASS / Wayland app_id — unique per app so each gets its own dock
      # icon and StartupWMClass association.
      identifier = "webapp-${site.id}";

      flags = [
        "--app=${lib.escapeShellArg site.url}"
        "--class=${identifier}"
        "--window-size=${toString site.width},${toString site.height}"
        "--no-first-run"
        "--no-default-browser-check"
      ] ++ lib.optional (!site.shareProfile)
        "--user-data-dir=${lib.escapeShellArg "${profileRoot}/${site.id}"}";

      launcher = pkgs.writeShellScriptBin identifier ''
        exec ${browserExe} ${lib.concatStringsSep " " flags} "$@"
      '';

      desktopItem = pkgs.makeDesktopItem {
        name = site.id;
        desktopName = site.name;
        exec = "${identifier} %U";
        icon =
          if site.icon != null then "${site.icon}" else "${iconDir}/${site.id}.png";
        comment = site.description;
        startupWMClass = identifier;
        categories = [ "Network" ];
      };
    in
    [ launcher desktopItem ];

  sites = map normalizeSite cfg.sites;
  autoIconSites = builtins.filter (s: s.icon == null) sites;
in
{
  options.kyan.webapps = {
    sites = lib.mkOption {
      type = with lib.types; listOf (either str attrs);
      default = [ ];
      description = ''
        Sites to package as standalone desktop web apps (Chromium --app windows).
        Each entry is either a bare URL string (name/icon auto-derived) or an
        attrset { url; name?; id?; icon?; description?; width?; height?;
        darkMode?; borderless?; shareProfile?; }. Launcher command is
        `webapp-<id>`; the launcher entry shows the friendly name. Auto-icon
        sites get their favicon fetched at activation time. `shareProfile = true`
        reuses the browser's default profile (existing logins) instead of an
        isolated per-app profile.
      '';
    };

    browser = lib.mkOption {
      type = lib.types.package;
      default = pkgs.helium;
      defaultText = lib.literalExpression "pkgs.helium";
      description = ''
        Chromium-based browser used as the web-app engine (launched with
        --app). Must accept Chromium flags (--app, --class, --user-data-dir).
      '';
    };
  };

  config = {
    home.packages = lib.concatMap buildWebApp sites;

    # Fetch a favicon per auto-icon site into ~/.local/share/webapps/icons at
    # activation time (impure, in-session — no build-time network). Falls back
    # to the generic globe icon on failure/offline; never a broken icon path.
    home.activation.webappIcons =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        iconDir="${iconDir}"
        $DRY_RUN_CMD mkdir -p "$iconDir"
        ${lib.concatMapStringsSep "\n" (s: ''
          dst="$iconDir/${s.id}.png"
          if [ ! -s "$dst" ]; then
            tmp="$(mktemp)"
            if ${pkgs.curl}/bin/curl -fsSL --max-time 10 "https://icon.horse/icon/${s.domain}" -o "$tmp" \
              || ${pkgs.curl}/bin/curl -fsSL --max-time 10 "https://icons.duckduckgo.com/ip3/${s.domain}.ico" -o "$tmp" \
              || ${pkgs.curl}/bin/curl -fsSL --max-time 10 "https://www.google.com/s2/favicons?domain=${s.domain}&sz=128" -o "$tmp"; then
              if ! ${pkgs.imagemagick}/bin/magick "$tmp[0]" -resize 256x256 "$dst" 2>/dev/null; then
                $DRY_RUN_CMD cp ${genericIcon} "$dst"
              fi
            else
              $DRY_RUN_CMD cp ${genericIcon} "$dst"
            fi
            rm -f "$tmp"
          fi
        '') autoIconSites}
      '';
  };
}
