{ config, lib, pkgs, inputs, osConfig ? { }, ... }:
let
  # Whether this host has the NVIDIA dGPU stack (g815 yes, Intel-only hosts
  # no) — gates the GPU bar widget, which reads via nvidia-smi.
  hasNvidia = (osConfig.kyan or { }).nvidia.enable or false;

  # The single keyboard-aura setter: paint the Aura keyboard to a given accent and
  # apply the effect/brightness appropriate to the current power source. Shared by
  # two triggers — the matugen aura template runs it as a post_hook on every
  # palette change (session start, wallpaper pick, light/dark flip, passing the
  # new accent), and power-tune (niri.nix) calls it on every power-source change
  # (passing the cached accent). Having one setter means the two triggers can't
  # disagree.
  #
  # By power source (see modules/nixos/mixins/power.nix `power-source`):
  #   ac        — static themed colour, full brightness.
  #   powerbank — slow breathe of the themed accent (a "charging" vibe) while still
  #               being treated as battery for power; full brightness.
  #   battery   — themed colour staged but brightness dropped to dark (so a later
  #               AC/relog brings the colour back). This is also the fix for the
  #               LEDs lighting up after a relog on battery: setting an Aura effect
  #               re-enables the backlight, so we re-assert the dark level here.
  # Runs inside DMS's systemd *user* service (limited PATH), so power-source is
  # pinned by absolute path; brightness is driven through asusd (asusctl leds) since
  # the user can't write the root-owned /sys LED node directly.
  auraRepaint = pkgs.writeShellApplication {
    name = "aura-repaint";
    runtimeInputs = [
      pkgs.asusctl
      pkgs.coreutils
    ];
    text = ''
      colour="''${1:?usage: aura-repaint <hex>}"
      case "$(/run/current-system/sw/bin/power-source 2>/dev/null || echo ac)" in
        ac)
          asusctl aura effect static -c "$colour" || true
          asusctl leds set high || true
          ;;
        powerbank)
          asusctl aura effect breathe --colour "$colour" --colour2 000000 --speed med || true
          asusctl leds set high || true
          ;;
        *)
          asusctl aura effect static -c "$colour" || true
          asusctl leds set off || true
          ;;
      esac
    '';
  };

  # Seed for ~/.config/DankMaterialShell/settings.json (activation block below):
  #
  #   - idle timeouts: disables every idle monitor DMS's IdleService.qml
  #     drives — screen-off, lock, and suspend, on both AC and battery. Same
  #     reason noctalia's idle was force-disabled: the internal panel (eDP-1)
  #     fails its wake modeset with `PHY A failed to request refclk` (see
  #     systems/g815/default.nix), and that modeset only happens coming back
  #     from a DPMS-off, so never blanking on idle dodges it. Manual
  #     lock/suspend (SUPER+SHIFT+Escape) is unaffected.
  #   - battery/profile notifications: DMS supports both natively (low-battery
  #     toast + a power-profile-change OSD) but ships them off by default;
  #     flip them on here for parity with noctalia's old always-on hooks.
  #   - customThemeFile: points at the Flexoki theme JSON below so it's ready
  #     the moment flexoki-pin (also below) or a manual Settings → Theme &
  #     Colors → Custom pick sets currentThemeName to "custom". Does NOT touch
  #     currentThemeName itself — DMS's own wallpaper-derived default stands
  #     until something (flexoki-pin, or the user) opts in.
  #   - currentThemeName "dynamic": SPEC's own default is "purple" (a fixed
  #     registry theme, not wallpaper-derived) — without this a fresh install
  #     shows purple until someone opens Settings and picks a theme. "dynamic"
  #     is Theme.qml's own sentinel for "wallpaper-derived" (`readonly property
  #     string dynamic: "dynamic"`), so this just makes the real default match
  #     the wallpaper-derived theming this whole file exists to drive.
  #   - cornerRadius 0 + barConfigs[0].squareCorners true: fully squared UI,
  #     matching the old Noctalia config (corner_radius_scale 0.0, bar radius
  #     0). cornerRadius is the single global radius Theme.qml applies to
  #     popups/notifications/dock/widgets; the bar has its own separate
  #     squareCorners flag, hence seeding the whole default barConfigs entry
  #     (SPEC.barConfigs.def) with just that one field flipped — DMS's loader
  #     doesn't deep-merge array values, so a partial object would drop the
  #     rest of the bar's config to `undefined`. niriLayoutRadiusOverride is
  #     left at its SPEC default (-1, off) — niri's own window-corner radius
  #     is out of scope here and already matches (see mixins/niri.nix).
  #   - showWorkspaceName + showOccupiedWorkspacesOnly: renders niri's named
  #     workspaces (wsName in mixins/niri.nix) on the bar's pills instead of
  #     bare indices, and hides empty ones — the closest match to Noctalia's
  #     old hide_when_empty=true + name-label behaviour. There's no per-widget
  #     "max name length" key upstream (WorkspaceSwitcher.qml renders the full
  #     name on a horizontal bar; it only truncates to the first character in
  #     vertical-bar orientation), so none is seeded.
  #   - no wallpaper-folder key: verified there isn't one. DMS has no
  #     directory-scanning wallpaper gallery — SettingsSpec.js/SessionSpec.js
  #     have no wallpaperFolder/wallpaperDirectory key at all. The Settings
  #     wallpaper picker (SettingsWallpaperPicker.qml) is a generic
  #     FileBrowserModal that opens to CacheData.wallpaperLastPath (a
  #     ~/.local/state/DankMaterialShell/cache.json field, outside
  #     SettingsSpec/SessionSpec — not reachable via `settings set` IPC or
  #     this seed) or falls back to $HOME. The only real per-mode wallpaper
  #     primitive is SessionSpec's wallpaperPath{Light,Dark} + perModeWallpaper
  #     (single files, not folders, and session.json isn't seeded by this
  #     activation block at all) — set live on this host via `dms ipc call
  #     wallpaper set` plus a direct session.json edit; not persisted here.
  #
  # Key names verified against upstream quickshell/Common/settings/SettingsSpec.js
  # (AvengeMedia/DankMaterialShell@74896fb): idle timeouts already default to 0
  # (= disabled), but they're pinned explicitly here rather than relying on
  # that staying true across DMS updates.
  customThemeFile = "${config.home.homeDirectory}/.config/DankMaterialShell/flexoki-theme.json";

  settingsSeed = pkgs.writeText "dms-settings-seed.json" (
    builtins.toJSON {
      acMonitorTimeout = 0;
      acLockTimeout = 0;
      acSuspendTimeout = 0;
      batteryMonitorTimeout = 0;
      batteryLockTimeout = 0;
      batterySuspendTimeout = 0;
      batteryNotifyLow = true;
      osdPowerProfileEnabled = true;
      inherit customThemeFile;
      currentThemeName = "dynamic";
      cornerRadius = 0;
      showWorkspaceName = true;
      showOccupiedWorkspacesOnly = true;
      # Weather follows real location: DMS's core resolves it via the system
      # geoclue2 service (mixins/geolocation.nix, WiFi positioning via beaconDB)
      # and only falls back to IP geolocation if geoclue is absent.
      # (weatherCoordinates lives in session.json, which we don't seed.)
      useAutoLocation = true;
      barConfigs = [
        {
          id = "default";
          name = "Main Bar";
          enabled = true;
          position = 0;
          screenPreferences = [ "all" ];
          showOnLastDisplay = true;
          leftWidgets = [ "launcherButton" "workspaceSwitcher" ];
          centerWidgets = [ "music" "clock" "weather" ];
          rightWidgets = [ "systemTray" "hiddenBar" "cpuUsage" ]
            ++ lib.optional hasNvidia "nvidiaGpuMonitor"
            ++ [ "memUsage" "claudeCodeUsage" "githubNotifier" "notificationButton" "battery" "controlCenterButton" ];
          spacing = 0;
          innerPadding = 4;
          bottomGap = 0;
          transparency = 1.0;
          widgetTransparency = 1.0;
          squareCorners = true;
          noBackground = false;
          maximizeWidgetIcons = false;
          maximizeWidgetText = false;
          removeWidgetPadding = false;
          widgetPadding = 8;
          gothCornersEnabled = false;
          gothCornerRadiusOverride = false;
          gothCornerRadiusValue = 12;
          borderEnabled = false;
          borderColor = "surfaceText";
          borderOpacity = 1.0;
          borderThickness = 1;
          widgetOutlineEnabled = false;
          widgetOutlineColor = "primary";
          widgetOutlineOpacity = 1.0;
          widgetOutlineThickness = 1;
          fontScale = 1.0;
          iconScale = 1.0;
          autoHide = false;
          autoHideStrict = false;
          autoHideDelay = 250;
          showOnWindowsOpen = false;
          openOnOverview = false;
          visible = true;
          popupGapsAuto = true;
          popupGapsManual = 4;
          maximizeDetection = true;
          useOverlayLayer = false;
          scrollEnabled = true;
          scrollXBehavior = "column";
          scrollYBehavior = "workspace";
          shadowIntensity = 0;
          shadowOpacity = 60;
          shadowColorMode = "default";
          shadowCustomColor = "#000000";
          clickThrough = false;
          hoverPopouts = false;
          hoverPopoutDelay = 150;
        }
      ];
    }
  );

  # Flexoki as a DMS custom theme (docs/CUSTOM_THEMES.md schema, AvengeMedia/
  # DankMaterialShell@74896fb): a hardcoded palette DMS loads instead of
  # matugen's wallpaper-derived one when currentThemeName == "custom" (see
  # Theme.qml switchTheme/loadCustomThemeFromFile). Values come straight from
  # users/kyandesutter/mixins/flexoki/palette.nix — the same base tones and
  # accent stops used everywhere else Flexoki is themed — mapped onto DMS's
  # M3 role set (a superset of the old Noctalia fixed_palette schema this
  # replaces; see `git show 3eaefc4:…/noctalia.nix:132-225` for that mapping).
  # Roles with no direct Noctalia equivalent (primaryContainer, surfaceTint,
  # backgroundText, the three surfaceContainer* elevation steps) are filled
  # from the same base-tone ramp rather than introducing new colours:
  # primaryContainer reuses the *other* blue stop (the "darker/lighter variant
  # of primary" docs call for), and surfaceContainer/-High/-Highest step one
  # base tone at a time away from surface/background, in the same direction
  # accents already lighten/darken between dark and light mode.
  flexokiTheme =
    let
      palette = import ./flexoki/palette.nix;
      inherit (palette) base accents;
    in
    {
      dark = {
        name = "Flexoki Dark";
        primary = accents.blue.d; # #4385BE
        primaryText = base.black;
        primaryContainer = accents.blue.l; # #205EA6
        secondary = accents.cyan.d; # #3AA99F
        surface = base.black;
        surfaceText = base.b200;
        surfaceVariant = base.b900;
        surfaceVariantText = base.b500;
        surfaceTint = accents.blue.d;
        background = base.black;
        backgroundText = base.b200;
        outline = base.b800;
        surfaceContainer = base.b950;
        surfaceContainerHigh = base.b900;
        surfaceContainerHighest = base.b850;
        error = accents.red.d; # #D14D41
        warning = accents.orange.d; # #DA702C
        info = accents.cyan.d;
      };
      light = {
        name = "Flexoki Light";
        primary = accents.blue.l; # #205EA6
        primaryText = base.paper;
        primaryContainer = accents.blue.d; # #4385BE
        secondary = accents.cyan.l; # #24837B
        surface = base.paper;
        surfaceText = base.black;
        surfaceVariant = base.b100;
        surfaceVariantText = base.b600;
        surfaceTint = accents.blue.l;
        background = base.paper;
        backgroundText = base.black;
        outline = base.b150;
        surfaceContainer = base.b50;
        surfaceContainerHigh = base.b100;
        surfaceContainerHighest = base.b150;
        error = accents.red.l; # #AF3029
        warning = accents.orange.l; # #BC5215
        info = accents.cyan.l;
      };
    };

  # DMS package, patched. `programs.dank-material-shell.package` defaults to
  # `dmsPkgs.dms-shell` (distro/nix/options.nix), a `buildGoModule` derivation
  # whose `src` is `./core` (the Go sources only) — the QML tree the patches
  # below target lives under `quickshell/`, copied into $out by `postInstall`
  # from a *separate* path (`rootSrc = ./.`, the whole repo), never unpacked
  # as `src`. That means the usual `patches = old.patches ++ [...]` (which
  # only patches `$src`) can't reach it — confirmed by inspecting `postInstall`
  # in the pinned flake's own flake.nix (`mkDmsShell`), not by guessing. So
  # this patches the copied-in tree in place, appended after the existing
  # `cp -r … $out/share/quickshell/dms/` in the same postInstall: the file is
  # a direct child of that freshly-created (writable) directory, so a `chmod`
  # + `patch` there works even though the *source* files `cp -r` copied it
  # from are read-only (the nix store). Built via the flake's own
  # `lib.mkDmsShell` (not `inputs.….packages.${system}`) so this stays on our
  # overlay-aware `pkgs`, matching exactly what the module's own default does
  # internally (`distro/nix/options.nix`: `dmsPkgs = buildDmsPkgs pkgs`).
  dmsPackage = (inputs.dank-material-shell.lib.mkDmsShell pkgs).overrideAttrs (old: {
    postInstall = old.postInstall + ''
      chmod u+w "$out/share/quickshell/dms/DMSShellIPC.qml"
      patch -p1 -d "$out/share/quickshell/dms" < ${./dms-ipc-settings-set.patch}
      chmod u+w "$out/share/quickshell/dms/Services" "$out/share/quickshell/dms/Services/LocationService.qml"
      patch -p1 -d "$out/share/quickshell/dms" < ${./dms-location-poll.patch}
    '';
  });

  # Reconciler: pin the Flexoki custom theme while a flexoki-named wallpaper
  # is active, and hand back to the wallpaper-derived theme otherwise —
  # restoring per-wallpaper Flexoki pinning without Noctalia's
  # wallpaper_changed hook (DMS has no such per-pick hook; see
  # wallpaper-engine.nix's header for the equivalent note re: the wallpaper
  # picker). Session state is DMS's own record of the applied wallpaper
  # (~/.local/state/DankMaterialShell/session.json, `wallpaperPath` —
  # SessionData.qml/SessionSpec.js), so watching it (rather than matugen's
  # `{{image}}`, which only fires for the single theming "target monitor")
  # catches every wallpaper pick DMS itself makes.
  #
  # Loop safety: this watches session.json only. Every write this reconciler
  # makes goes through `dms ipc call settings set`, which lands in
  # settings.json (a completely different file, never watched here) — so a
  # write here can never retrigger the watch that produced it.
  #
  # Matching mirrors the old Noctalia `flexoki-scheme` hook's
  # `[[ "$path" == *flexoki* ]]` substring test (case-insensitive,
  # `git show 3eaefc4:…/noctalia.nix:87-88`). Idempotent: settings.json is
  # read before every write, and nothing is written when the sentinel already
  # matches — the ONLY way this can visibly re-apply the custom theme is a
  # genuine wallpaper flip, thanks to the patched IPC handler above actually
  # dispatching Theme.switchTheme instead of silently writing a dead setting.
  flexokiPin = pkgs.writeShellApplication {
    name = "flexoki-pin";
    runtimeInputs = [
      dmsPackage
      pkgs.inotify-tools
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      settings="$HOME/.config/DankMaterialShell/settings.json"
      statedir="$HOME/.local/state/DankMaterialShell"
      session="$statedir/session.json"
      mkdir -p "$statedir"
      shopt -s nocasematch

      # No-ops gracefully if either file doesn't exist yet (settings.json is
      # seeded by home-manager activation before this service ever starts;
      # session.json only appears once DMS itself has run and saved a
      # session) — the surrounding inotify watch on $statedir still works on
      # an empty/fresh directory, so the very next write picks this back up.
      reconcile() {
        [[ -r "$session" && -r "$settings" ]] || return 0
        local wallpaper current
        wallpaper="$(jq -r '.wallpaperPath // empty' "$session" 2>/dev/null || true)"
        current="$(jq -r '.currentThemeName // empty' "$settings" 2>/dev/null || true)"
        if [[ "$wallpaper" == *flexoki* ]]; then
          [[ "$current" == "custom" ]] || dms ipc call settings set currentThemeName custom || true
        else
          [[ "$current" != "custom" ]] || dms ipc call settings set currentThemeName dynamic || true
        fi
      }

      trap 'exit 0' TERM INT

      reconcile
      while read -r _; do
        # Coalesce bursts (a wallpaper pick can touch session.json more than
        # once in quick succession) so a single flip doesn't fire the IPC
        # call twice.
        while read -r -t 0.4 _; do :; done
        reconcile
      done < <(inotifywait -q -m -e close_write,create,moved_to "$statedir")
    '';
  };
in
{
  # Official DankMaterialShell flake home-manager module. DMS is a Quickshell/QML
  # desktop shell. The module installs the `dms-shell` package + runs it as a user
  # systemd service bound to the Wayland systemd target (auto-starts once niri
  # reaches that target).
  imports = [
    inputs.dank-material-shell.homeModules.dank-material-shell
    # Registers every community plugin as
    # `programs.dank-material-shell.plugins.<id>` (all disabled by default); the
    # ones enabled below get their fetchgit'd source symlinked into
    # ~/.config/DankMaterialShell/plugins/<id>.
    inputs.dms-plugin-registry.homeModules.default
  ];

  # Expose aura-repaint on PATH so power-tune (niri.nix) can call it as the
  # shared keyboard-aura setter (the matugen aura template's post_hook also uses
  # it, by store path). jq rides along for the DankBar plugins that shell out to
  # it (claudeCodeUsage, nixPackageRunner) — DMS's user service inherits the home
  # profile on PATH.
  home.packages = [ auraRepaint pkgs.jq ];

  programs.dank-material-shell = {
    enable = true;
    systemd.enable = true; # user service, PartOf the Wayland/graphical-session target
    enableDynamicTheming = true; # pulls in the deps DMS's own theming needs
    package = dmsPackage; # local patches: IPC `settings set` → SettingsData.set, location poll (see dmsPackage above)

    # Community plugins from inputs.dms-plugin-registry (imported above). Only
    # `.enable` is set here — no `.settings`, which deliberately keeps
    # managePluginSettings off so plugin_settings.json stays runtime-mutable
    # (the plugins persist their own config there, and it's seeded with
    # `enabled: true` by the activation block below). All four are dankbar/
    # launcher surfaces, not daemons.
    plugins = {
      # NVIDIA usage / VRAM / temperature. Reads via nvidia-smi, so it only
      # shows data when the dGPU is powered (blank on battery, by design). The
      # dgpuStatus D0/D3cold power-state widget was dropped by preference — this
      # usage widget is the only GPU pill on the bar.
      nvidiaGpuMonitor.enable = hasNvidia;
      # Emoji & Unicode launcher — bound to Mod+Period in mixins/niri.nix via
      # `spotlight toggleQuery :e` (:e is the plugin's default trigger).
      emojiLauncher.enable = true;

      # Launcher-only plugins (spotlight surfaces, no bar widget). Both seed
      # `enabled: true` below so they index without a manual Settings toggle.
      # calculator: evaluate expressions, copy result. nixPackageRunner: search
      # nixpkgs / `nix run` from the launcher (needs nix + jq + wl-clipboard,
      # all on PATH).
      calculator.enable = true;
      nixPackageRunner.enable = true;

      # DankBar widgets. Bar placement is spliced into rightWidgets by the seed
      # (settingsSeed above) and, for the already-provisioned live bar, by
      # dms-bar-plugins.jq — both kept in the same order.
      # githubNotifier: open PRs authored by you + issues assigned to you. Reads
      # via `gh` (present) — run `gh auth login` once; the GitHub brand glyph
      # needs font-awesome (added to fonts.packages in mixins/niri.nix).
      githubNotifier.enable = true;
      # claudeCodeUsage: token usage / rate limits / daily charts for the Claude
      # Code subscription. Parses ~/.claude logs with jq (added to home.packages).
      claudeCodeUsage.enable = true;
      # hiddenBar: macOS-Hidden-Bar-style toggle pill that collapses widgets in
      # its section. Seeded right of systemTray in rightWidgets (above) so the
      # tray sits in its manageable zone; the plugin_settings seed below pins it
      # to whitelist mode targeting "systemTray", so a click hides only the tray.
      hiddenBar.enable = true;

      # Scriptable custom bar buttons (Avenge Media, first-party) — the
      # replacement for noctalia's old custom "Windows" power-menu button, which
      # DMS's own powermenu can't host (fixed action enum; see the desktop-entry
      # note near the bottom of this file). Uses DMS's plugin-variant system:
      # each action is its own bar widget created at runtime (Settings → Plugins
      # → Dank Actions), so nothing is spliced onto the bar here. Configure one
      # variant with the left-click command
      # `systemctl start reboot-to-windows.service` to restore the one-click
      # boot-to-Windows button (the reboot-to-windows.service + polkit waiver in
      # modules/nixos/mixins/boot.nix already exist).
      dankActions.enable = true;
    };
  };

  # App theming beyond DMS's builtin templates (gtk3/gtk4, qt5ct/qt6ct, ghostty,
  # …, all unconditionally detected + rendered by DMS itself — see
  # AvengeMedia/DankMaterialShell core/internal/matugen/matugen.go
  # templateRegistry). These `user` templates push the same live wallpaper
  # palette into apps DMS can't theme natively. Sources are installed to
  # ~/.config/matugen/templates/ below; `.default` colour tokens track the
  # active mode, so each output is rewritten on every mode flip / wallpaper
  # change DMS runs matugen for. post_hook strings are themselves rendered
  # through the engine (colour tokens interpolated) before running.
  # Profile picture: DMS reads the avatar from AccountsService
  # (PortalService.getUserIconFile → HeaderPane), and AccountsService falls back
  # to ~/.face when no icon is set — so seeding it here themes the DMS control
  # centre and the SDDM greeter from one source.
  home.file.".face".source = ../assets/profile.jpeg;

  xdg.configFile = {
    # DMS custom theme (flexokiTheme above): a plain declarative file, unlike
    # settings.json/session.json below — DMS only ever reads it, never
    # rewrites it, so it needs no seed-if-absent dance.
    "DankMaterialShell/flexoki-theme.json".text = builtins.toJSON flexokiTheme;

    "matugen/templates/aura.tmpl".source = ../matugen-templates/aura.tmpl;
    "matugen/templates/ghostty.tmpl".source = ../matugen-templates/ghostty.tmpl;
    "matugen/templates/neovim.lua.tmpl".source = ../matugen-templates/neovim.lua.tmpl;
    "matugen/templates/equibop.css.tmpl".source = ../matugen-templates/equibop.css.tmpl;
    "matugen/templates/spicetify.ini.tmpl".source = ../matugen-templates/spicetify.ini.tmpl;
    "matugen/templates/obsidian.css.tmpl".source = ../matugen-templates/obsidian.css.tmpl;
    "matugen/templates/niri-border.kdl.tmpl".source = ../matugen-templates/niri-border.kdl.tmpl;
    "matugen/templates/btop.theme.tmpl".source = ../matugen-templates/btop.theme.tmpl;
    "matugen/templates/yazi-flavor.toml.tmpl".source = ../matugen-templates/yazi-flavor.toml.tmpl;
    "matugen/templates/wallpaper-path.tmpl".source = ../matugen-templates/wallpaper-path.tmpl;
    "matugen/templates/zen-vars.json.tmpl".source = ../matugen-templates/zen-vars.json.tmpl;

    # DMS reads ~/.config/matugen/config.toml on every re-theme and splices its
    # [config] and [templates] sections verbatim into the matugen invocation it
    # runs itself (buildMergedConfig in matugen.go) — so this is matugen's own
    # TOML syntax, not a DMS-specific format. A bare `[templates]` header is
    # required before the first `[templates.*]` subtable: DMS's merge locates
    # the literal substring "[templates]", which "[templates.aura]" alone does
    # not contain. `~` in input_path/output_path is expanded by matugen itself.
    "matugen/config.toml".text = ''
      [config]

      [templates]

      # ASUS Aura keyboard. Output file doubles as the "current accent" cache
      # that power-tune (niri.nix) reads to restore today's colour on a
      # power-source change; the post_hook does the actual repaint.
      [templates.aura]
      input_path = "~/.config/matugen/templates/aura.tmpl"
      output_path = "~/.cache/dank/aura-color"
      post_hook = "${auraRepaint}/bin/aura-repaint {{colors.primary.default.hex_stripped}}"

      # Ghostty: written into ghostty's themes dir; config references it with
      # `theme = "Matugen"` (see mixins/ghostty.nix). SIGUSR2 live-reloads it
      # (ghostty >= 1.2) without a restart. DMS's own builtin ghostty template
      # writes a separate `themes/dankcolors` file we don't reference, so the
      # two don't conflict.
      [templates.ghostty]
      input_path = "~/.config/matugen/templates/ghostty.tmpl"
      output_path = "~/.config/ghostty/themes/Matugen"
      post_hook = "pkill -SIGUSR2 ghostty || true"

      # Neovim: base16 lua module consumed by dynamic-base16.nvim (watch =
      # true) — no hook needed, the plugin watches the file. See neovim.nix.
      [templates.neovim]
      input_path = "~/.config/matugen/templates/neovim.lua.tmpl"
      output_path = "~/.config/nvim/lua/dank_base16.lua"

      # Equibop (Discord): Equicord hot-reloads the themes folder, so no hook.
      # One-time: enable the theme in Equibop -> Settings -> Themes.
      [templates.equibop]
      input_path = "~/.config/matugen/templates/equibop.css.tmpl"
      output_path = "~/.config/equibop/themes/dank.theme.css"

      # Spotify via spicetify. Writes the Comfy theme's color.ini, then
      # re-applies it to the (Flatpak) Spotify — see mixins/spicetify.nix.
      # Absolute spicetify path: this hook runs inside DMS's systemd user
      # service, whose PATH won't include the home profile bin. If the UI
      # doesn't visibly recolour, Ctrl+Shift+R inside Spotify forces it.
      #
      # The config dir is selected via the SPICETIFY_CONFIG env var, NOT a
      # `-c <path>` flag: in spicetify-cli v2 `-c`/`--config` is a standalone,
      # non-chainable flag that just prints the config path and exits, so
      # `spicetify -c <path> apply` silently runs nothing (exit 0) and Spotify
      # never gets re-patched. Setting SPICETIFY_CONFIG points apply at this
      # config dir explicitly (the systemd service may not have XDG_CONFIG_HOME).
      [templates.spicetify]
      input_path = "~/.config/matugen/templates/spicetify.ini.tmpl"
      output_path = "~/.config/spicetify/Themes/Comfy/color.ini"
      post_hook = "SPICETIFY_CONFIG=${config.home.homeDirectory}/.config/spicetify ${pkgs.spicetify-cli}/bin/spicetify apply --no-restart || true"

      # Obsidian (Minimal theme). Rendered into the vault's snippet dir;
      # Obsidian watches ~/Notes/.obsidian/snippets and hot-reloads on write,
      # so no post_hook. macOS rides Minimal's built-in Flexoki preset instead
      # — no DMS there — so this template is Linux-only (dms.nix is
      # g815-only). scripts/obsidian-vault-bootstrap.sh seeds an empty enabled
      # snippet before the first render.
      [templates.obsidian]
      input_path = "~/.config/matugen/templates/obsidian.css.tmpl"
      output_path = "~/Notes/.obsidian/snippets/dank.css"

      # niri window borders. DMS doesn't touch the compositor; this renders the
      # wallpaper palette into the layout fragment niri's config.kdl includes
      # (include optional=true, placed LAST so it overrides the rendered
      # defaults — see mixins/niri.nix), and the post_hook reloads niri's
      # config so the colours apply instantly. mixins/niri.nix seeds a Flexoki
      # fallback copy for the first login before the first render here.
      # primary = active border; error = urgent; outline = inactive.
      [templates.niri-border]
      input_path = "~/.config/matugen/templates/niri-border.kdl.tmpl"
      output_path = "~/.cache/dank/niri-border.kdl"
      post_hook = "${pkgs.niri}/bin/niri msg action load-config-file || true"

      # btop. DMS has no builtin btop template; programs.btop.settings.color_theme
      # in programs.nix points at this output. Picks up colours on next launch
      # (no live reload).
      [templates.btop]
      input_path = "~/.config/matugen/templates/btop.theme.tmpl"
      output_path = "~/.config/btop/themes/dank.theme"

      # yazi. DMS has no builtin yazi template; programs.yazi.theme in
      # programs.nix points ~/.config/yazi/theme.toml's [flavor] dark/light at
      # "dank", so this one output covers both modes. Picks up colours on next
      # yazi launch (no live reload).
      [templates.yazi]
      input_path = "~/.config/matugen/templates/yazi-flavor.toml.tmpl"
      output_path = "~/.config/yazi/flavors/dank.yazi/flavor.toml"

      # Wallpaper Engine reconciler hook (mixins/wallpaper-engine.nix). matugen
      # exposes the source image path as {{image}} on every re-theme; this
      # renders it to a cache file (any future consumer can `cat` it, same
      # doubles-as-cache pattern as templates.aura above) and the post_hook
      # feeds that same path straight to wallpaper-engine-select, which
      # records/clears the picked WE scene for the reconciler's already-
      # running inotify watch to pick up. Parity replacement for noctalia's
      # old wallpaper_changed hook — see that mixin for why the per-output
      # tracking it used to do doesn't carry over (matugen only fires for
      # DMS's single theming "target monitor" image, no per-output signal).
      [templates.wallpaper-path]
      input_path = "~/.config/matugen/templates/wallpaper-path.tmpl"
      output_path = "~/.cache/dank/wallpaper-path"
      post_hook = "${config.kyan.wallpaperEngine.selectCommand} {{image}}"

      # Zen browser (zen-wabi bridge, mixins/zen.nix). Renders the 8-colour
      # contract wabi's matugen-bridge.uc.js polls (1s mtime check) inside the
      # profile's chrome dir; the bridge pushes the values live into chrome and
      # content via prefs + a JSWindowActor, so no post_hook and no browser
      # restart. First-paint Flexoki fallbacks are baked into userChrome.css.
      [templates.zen]
      input_path = "~/.config/matugen/templates/zen-vars.json.tmpl"
      output_path = "~/.config/zen/default/chrome/matugen-vars.json"
    '';
  };

  # settings.json is DMS's own runtime-mutable config (rewritten by the Settings
  # UI and by DMS itself on every save), so home-manager must not own the whole
  # file. Two modes, both minimal:
  #   - absent: seed it wholesale from settingsSeed above, so idle stays
  #     disabled and battery/profile notifications are on from the very first
  #     session rather than however long it takes to open Settings manually.
  #   - present: back-fill two things, both idempotently. The customThemeFile
  #     key when absent (covers a re-install landing on a settings.json that
  #     already exists — without it flexoki-pin flips currentThemeName to
  #     "custom" with no palette to load; never touches an existing key, even
  #     "", which could be a deliberate user clear). And the plugin bar widgets
  #     (dms-bar-plugins.jq), spliced into the live bar the same way the seed
  #     places them — each id added only when missing from the whole bar, so a
  #     widget the user later moves or removes isn't duplicated on the next
  #     switch. The file is only rewritten when that pass actually changes it.
  home.activation.dmsSettingsSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.config/DankMaterialShell/settings.json"
    if [ ! -e "$settings" ]; then
      run mkdir -p "$HOME/.config/DankMaterialShell"
      run cp --no-preserve=mode ${settingsSeed} "$settings"
    else
      tmp="$(mktemp "$settings.XXXXXX")"
      ${pkgs.jq}/bin/jq 'if has("customThemeFile") then . else . + {customThemeFile: "${customThemeFile}"} end' "$settings" \
        | ${pkgs.jq}/bin/jq -f ${./dms-bar-plugins.jq} > "$tmp"
      if ${pkgs.jq}/bin/jq -e --slurpfile a "$tmp" '. == $a[0]' "$settings" >/dev/null; then
        rm -f "$tmp"
      else
        chmod --reference="$settings" "$tmp"
        run mv "$tmp" "$settings"
      fi
    fi
  '';

  # plugin_settings.json holds each plugin's enabled flag plus its own
  # runtime-written config. The registry HM module only manages this file when a
  # plugin declares `.settings` (we deliberately don't — see plugins above), so
  # DMS owns it; we just seed `enabled: true` for the plugins wired in above so
  # they load on the first session with no manual Settings → Plugins toggle.
  # Only a missing top-level id is added — an existing entry (even
  # {enabled:false}) is left as a deliberate user choice. Rewritten only when
  # the seed actually adds something.
  home.activation.dmsPluginSettingsSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    pf="$HOME/.config/DankMaterialShell/plugin_settings.json"
    run mkdir -p "$HOME/.config/DankMaterialShell"
    [ -e "$pf" ] || echo '{}' > "$pf"
    tmp="$(mktemp "$pf.XXXXXX")"
    ${pkgs.jq}/bin/jq '
      reduce (
        ${lib.optionalString hasNvidia ''"nvidiaGpuMonitor",''} "emojiLauncher",
        "calculator", "nixPackageRunner", "githubNotifier",
        "claudeCodeUsage", "dankActions"
      ) as $id
        (.; if has($id) then . else .[$id] = { enabled: true } end)
    # hiddenBar needs more than the enabled flag: whitelist mode pinned to the
    # system tray so the toggle hides only that widget (see plugins.hiddenBar).
    | if has("hiddenBar") then . else
        .hiddenBar = { enabled: true, widgetSelectionMode: "whitelist", widgetWhitelist: ["systemTray"] }
      end
    ' "$pf" > "$tmp"
    if ${pkgs.jq}/bin/jq -e --slurpfile a "$tmp" '. == $a[0]' "$pf" >/dev/null; then
      rm -f "$tmp"
    else
      run mv "$tmp" "$pf"
    fi
  '';

  # flexokiPin above: watches session.json, pins/unpins the Flexoki custom
  # theme via the patched IPC handler. Same graphical-session.target wiring
  # as wallpaper-engine.nix's reconciler — restarts on a rebuild that changes
  # the script, re-reads state on startup.
  systemd.user.services.flexoki-pin = {
    Unit = {
      Description = "Pin the Flexoki custom theme for flexoki-named wallpapers";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      ExecStart = "${flexokiPin}/bin/flexoki-pin";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # Fallback for the two power-menu actions DMS's own powermenu can't host:
  # its action set is a fixed enum (SettingsData.powerMenuActions — reboot/
  # logout/poweroff/lock/suspend/restart/hibernate/switchuser, see
  # PowerMenuModal.qml upstream), with no custom-command entry, so "Reboot to
  # Windows" and "UEFI Firmware Setup" can't be wired in declaratively there.
  # These show up in DMS's spotlight launcher instead (it indexes
  # ~/.local/share/applications like any XDG app launcher). The polkit rules
  # waiving the password for both (modules/nixos/mixins/boot.nix) are scoped
  # to the active local wheel session generally, not to any particular
  # caller, so launching from here needs no extra grant.
  xdg.desktopEntries = {
    reboot-to-windows = {
      name = "Reboot to Windows";
      exec = "/run/current-system/sw/bin/systemctl start reboot-to-windows.service";
      icon = "system-reboot";
      terminal = false;
      categories = [ "System" ];
    };
    uefi-firmware-setup = {
      name = "UEFI Firmware Setup";
      exec = "/run/current-system/sw/bin/systemctl reboot --firmware-setup";
      # Colloid-Dark only ships org.gnome.Firmware as a *symbolic* icon (no
      # matching non-symbolic entry), so use the icon theme's regular
      # preferences-system glyph instead of risking a blank icon.
      icon = "preferences-system";
      terminal = false;
      categories = [ "System" ];
    };
  };
}
