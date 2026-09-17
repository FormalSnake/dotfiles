{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.webapps;

  # Engine: Helium in --app mode (one window, no browser chrome), started
  # through the takeover guard in mixins/helium.nix rather than the bare
  # binary. The guard adds --password-store=basic, without which the synced
  # profile's cookies are unreadable and a profile-sharing app opens logged
  # out, and it quits the peer laptop's Helium first. Absolute profile path:
  # launchers run from the shell's systemd service, whose PATH lacks it.
  browserExe = "${config.home.profileDirectory}/bin/helium";

  # Isolated per-app user-data dirs and activation-fetched favicons.
  dataRoot = "${config.home.homeDirectory}/.local/share/webapps";
  profileRoot = "${dataRoot}/profiles";
  iconDir = "${dataRoot}/icons";
  genericIcon = ./webapps-icons/generic.png;

  domainOf = url:
    let noScheme = lib.last (lib.splitString "//" url);
    in lib.head (lib.splitString "/" noScheme);

  # claude.ai -> "Claude", www.x.co -> "X"
  deriveName = url:
    let
      host = lib.removePrefix "www." (domainOf url);
      labels = lib.splitString "." host;
      n = lib.length labels;
      primary = if n >= 2 then lib.elemAt labels (n - 2) else lib.head labels;
    in lib.toUpper (lib.substring 0 1 primary) + lib.substring 1 (builtins.stringLength primary) primary;

  normalizeSite = raw:
    let
      s = if builtins.isString raw then { url = raw; } else raw;
      name = s.name or (deriveName s.url);
    in {
      inherit (s) url;
      inherit name;
      id = s.id or (lib.toLower (builtins.replaceStrings [ " " ] [ "-" ] name));
      width = s.width or 1200;
      height = s.height or 800;
      # A Helium profile directory ("Default" is Personal) to reuse its
      # logins, or null for an isolated user-data dir. A shared-profile window
      # joins the running browser process, which ignores --class, so it
      # carries Helium's app_id rather than its own.
      profile = s.profile or null;
      icon = s.icon or null;
      domain = domainOf s.url;
    };

  buildWebApp = site:
    let
      identifier = "webapp-${site.id}";

      flags = [
        "--app=${lib.escapeShellArg site.url}"
        "--class=${identifier}"
        "--window-size=${toString site.width},${toString site.height}"
        "--no-first-run"
        "--no-default-browser-check"
      ] ++ (if site.profile != null
        then [ "--profile-directory=${lib.escapeShellArg site.profile}" ]
        else [ "--user-data-dir=${lib.escapeShellArg "${profileRoot}/${site.id}"}" ]);

      launcher = pkgs.writeShellScriptBin identifier ''
        exec ${browserExe} ${lib.concatStringsSep " " flags} "$@"
      '';

      desktopItem = pkgs.makeDesktopItem {
        name = site.id;
        desktopName = site.name;
        exec = "${launcher}/bin/${identifier} %U";
        icon = if site.icon != null then "${site.icon}" else "${iconDir}/${site.id}.png";
        startupWMClass = identifier;
        categories = [ "Network" ];
      };
    in
    [ launcher desktopItem ];

  sites = map normalizeSite cfg.sites;
in
{
  options.kyan.webapps.sites = lib.mkOption {
    type = with lib.types; listOf (either str attrs);
    default = [ ];
    description = ''
      Sites packaged as desktop web apps (Helium --app windows). A bare URL
      string, or { url; name?; id?; icon?; width?; height?; profile?; }.
      The launcher command is `webapp-<id>`.
    '';
  };

  config = {
    home.packages = lib.concatMap buildWebApp sites;

    # Favicons are fetched at activation, not build time (no network in the
    # sandbox), and fall back to the generic globe so the path never dangles.
    home.activation.webappIcons = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${iconDir}"
      ${lib.concatMapStringsSep "\n" (s: ''
        dst="${iconDir}/${s.id}.png"
        if [ ! -s "$dst" ]; then
          tmp="$(mktemp)"
          if ${pkgs.curl}/bin/curl -fsSL --max-time 10 "https://icon.horse/icon/${s.domain}" -o "$tmp" \
            || ${pkgs.curl}/bin/curl -fsSL --max-time 10 "https://www.google.com/s2/favicons?domain=${s.domain}&sz=128" -o "$tmp"; then
            ${pkgs.imagemagick}/bin/magick "$tmp[0]" -resize 256x256 "$dst" 2>/dev/null || run cp ${genericIcon} "$dst"
          else
            run cp ${genericIcon} "$dst"
          fi
          rm -f "$tmp"
        fi
      '') (builtins.filter (s: s.icon == null) sites)}
    '';
  };
}
