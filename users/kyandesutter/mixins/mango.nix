{ pkgs, config, lib, osConfig ? { }, ... }:
let
  flexoki = import ./flexoki/palette.nix;
  workspaces = import ./wm-workspaces.nix;

  # mango only carries FormalShell binds: DMS is dormant on both hosts and
  # never learned to talk to mango.
  useFormalshell = (((osConfig.kyan or { }).desktop or { }).shell or "dms") == "formalshell";
  fsBin = "${config.programs.formalshell.package}/bin/formalshell";
  fsIpc = args: "${fsBin} ipc --any-display call " + lib.concatStringsSep " " args;
  fsRadius = toString ((config.programs.formalshell.settings.theme or { }).radius or 10);
  wpctl = "${pkgs.wireplumber}/bin/wpctl";

  # Same gates as mixins/hyprland.nix: the g815 is the dGPU host with the
  # desk monitor, everything else is one internal panel.
  hasNvidia = (osConfig.kyan or { }).nvidia.enable or false;
  windowOpacity = if hasNvidia then "0.96" else "1.0";

  # mango colours are 0xRRGGBBAA.
  hex = c: "0x${lib.removePrefix "#" c}ff";

  # Monitor specs (dispatchers and window_rule) match make/model, the same
  # EDID identity hl.monitor's `desc:` uses, so the panel is found whichever
  # driver names its connector.
  panelSpec = "make:BOE&&model:NE180QDM-NZC";
  deskSpec = "HDMI-A-1";
  homeMonitor = i: if builtins.elem i workspaces.internal then panelSpec else deskSpec;

  # Tags are per monitor in mango (the dwl model), where Hyprland has one set
  # of workspaces each pinned to a monitor. On the g815 viewcrossmon and
  # tagcrossmon give each number its Hyprland home monitor back; with the
  # desk monitor unplugged focusmon finds nothing and the tag opens on the
  # panel, as Hyprland's relocation did.
  viewTag = i: if hasNvidia then "viewcrossmon,${toString i},${homeMonitor i}" else "view,${toString i}";
  moveTag = i: if hasNvidia then "tagcrossmon,${toString i},${homeMonitor i}" else "tag,${toString i}";

  # Monitors. g815: the desk monitor at the origin (the X11 primary, where
  # fullscreen games land) and the panel to its right at 1.25. VRR stays off:
  # always-on VRR flickers both panels on an idle desktop (see
  # mixins/hyprland.nix), and mango has no Hyprland-style vrr = 3.
  monitors =
    if hasNvidia then ''
      monitor_rule=name:^HDMI-A-1$,width:2560,height:1440,refresh:144,x:0,y:0,scale:1,vrr:0,primary:1
      monitor_rule=make:BOE,model:NE180QDM-NZC,width:2560,height:1600,refresh:240,x:2560,y:0,scale:1.25,vrr:0
    '' else ''
      monitor_rule=name:^eDP-1$,x:0,y:0,scale:1
    '';

  appRule = a:
    let
      match = if a ? class then "app_id:${a.class}" else "title:${a.title}";
      monitor = lib.optionalString hasNvidia "monitor:${homeMonitor a.workspace},";
    in
    "window_rule=tags:${toString a.workspace},${monitor}${match}";

  # Blur behind the shell's card-sized layers. Unlike Hyprland's
  # ignore_alpha, mango blurs a layer's whole rectangle, so the full-output
  # layers (bar, frame, and the scrim under menu, polkit, plugin overlay and
  # radio) go unblurred instead of frosting the entire desktop.
  unblurredLayers = [ "bar" "frame" "menu" "polkit" "plugin-overlay" "radio" "notifications" ];

  # Tag -> regex on the monitor name it lives on. The panel is matched by
  # connector prefix here, since mango's IPC reports names only.
  homes = lib.optionalAttrs hasNvidia (lib.listToAttrs (map
    (i: lib.nameValuePair (toString i) (if builtins.elem i workspaces.internal then "^eDP-" else "^HDMI-A-1$"))
    (lib.range 1 9)));

  # What mango's config cannot say and Hyprland did:
  #   - Mod+Tab goes to the previously focused workspace across monitors
  #     (mango's `view,-1` is per monitor), tracked here from all-monitors.
  #   - A workspace belongs to one monitor. mango moves windows back when a
  #     monitor returns, but only windows that were on it when it left; ones
  #     opened on a home-less tag meanwhile are sent home here too.
  #   - Floating Helium windows (document PiP) go on every tag, sized and
  #     tucked bottom-right. A window_rule cannot match on floating state.
  mangoRules = pkgs.writers.writePython3Bin "mango-rules"
    {
      flakeIgnore = [ "E501" ];
    } ''
    import json
    import os
    import re
    import subprocess
    import sys
    import threading

    MMSG = "${osConfig.programs.mango.package}/bin/mmsg"
    HOMES = {int(t): re.compile(r) for t, r in json.loads(${lib.escapeShellArg (builtins.toJSON homes)}).items()}
    STATE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "mango-rules-previous")
    PIP = re.compile(r"^helium$")
    MARGIN = 16


    def dispatch(*args):
        subprocess.run([MMSG, "dispatch", *args], check=False)


    def home(tag, monitors):
        pattern = HOMES.get(tag)
        if pattern is None:
            return None
        return next((m["name"] for m in monitors if pattern.search(m["name"])), None)


    class Rules:
        def __init__(self):
            self.lock = threading.Lock()
            self.clients = []
            self.monitors = []
            self.current = None
            self.placed = set()

        def on_monitors(self, monitors):
            with self.lock:
                self.monitors = monitors
                active = next((m for m in monitors if m.get("active")), None)
                if active and active.get("active_tags"):
                    focused = (active["active_tags"][0], active["name"])
                    if focused[0] != 0 and focused != self.current:
                        if self.current is not None:
                            with open(STATE, "w") as f:
                                f.write("%d %s\n" % self.current)
                        self.current = focused
                self.reconcile()

        def on_clients(self, clients):
            with self.lock:
                self.clients = clients
                self.reconcile()

        def reconcile(self):
            alive = {c["id"] for c in self.clients}
            self.placed &= alive
            for c in self.clients:
                tags = c.get("tags") or []
                if len(tags) == 1 and not c.get("is_global"):
                    target = home(tags[0], self.monitors)
                    if target and c.get("monitor") != target:
                        dispatch("tagmon,%s,1" % target, "client,%d" % c["id"])
                if c["id"] not in self.placed and c.get("is_floating") and PIP.match(c.get("appid") or ""):
                    self.place(c)

        def place(self, c):
            mon = next((m for m in self.monitors if m["name"] == c.get("monitor")), None)
            if mon is None:
                return
            self.placed.add(c["id"])
            width = int(mon["width"] * 0.28)
            height = int(mon["height"] * 0.28)
            x = mon["x"] + mon["width"] - width - MARGIN
            y = mon["y"] + mon["height"] - height - MARGIN
            ident = "client,%d" % c["id"]
            if not c.get("is_global"):
                dispatch("toggleglobal", ident)
            dispatch("resizewin,%d,%d" % (width, height), ident)
            dispatch("movewin,%d,%d" % (x, y), ident)


    def watch(topic, handler):
        proc = subprocess.Popen([MMSG, "watch", topic], stdout=subprocess.PIPE, text=True)
        for line in proc.stdout:
            line = line.strip()
            if line:
                handler(json.loads(line))
        sys.exit("mmsg watch %s ended" % topic)


    def previous():
        try:
            with open(STATE) as f:
                tag, monitor = f.read().split()
        except (OSError, ValueError):
            return
        dispatch("viewcrossmon,%s,%s" % (tag, monitor))


    if len(sys.argv) > 1 and sys.argv[1] == "previous":
        previous()
    else:
        rules = Rules()
        threading.Thread(target=watch, args=("all-monitors", rules.on_monitors), daemon=True).start()
        watch("all-clients", rules.on_clients)
  '';
in
lib.mkIf useFormalshell {
  # 0.18 syntax (flake input `mango`): key=value lines, later lines win, and
  # every source_optional'd file is watched and hot-reloaded. Parse-check with
  # `mango -c ~/.config/mango/config.conf -p`.
  xdg.configFile."mango/config.conf".text = ''
    # Colours and chrome: the static Flexoki fallback first, then FormalShell's
    # live palette and theme chrome (rendered on every wallpaper or mode
    # change) override it from the two files sourced below.
    focus_color=${hex flexoki.accents.blue.d}
    border_color=${hex flexoki.base.b700}
    urgent_color=${hex flexoki.accents.red.d}
    border_px=2
    border_radius=${fsRadius}
    # Hyprland's gaps_in is per side, so 4 there is 8 between windows here.
    gap_inner_horizontal=8
    gap_inner_vertical=8
    gap_outer_horizontal=8
    gap_outer_vertical=8
    shadows=0
    source_optional=~/.config/mango/formalshell-colors.conf
    source_optional=~/.config/mango/formalshell-chrome.conf

    # Monitors
    ${monitors}
    # Environment. XCURSOR_* for XWayland clients; the Qt picks are also in
    # ~/.config/uwsm/env for systemd user services.
    env=XCURSOR_THEME,Bibata-Modern-Classic
    env=XCURSOR_SIZE,24
    env=QT_QPA_PLATFORMTHEME,qt6ct
    cursor_theme=Bibata-Modern-Classic
    cursor_size=24

    # Input
    xkb_rules_layout=es
    xkb_rules_options=caps:escape
    repeat_rate=40
    repeat_delay=250
    # Click to focus, hover still delivers pointer events (Hyprland's
    # follow_mouse = 2), and keyboard focus never warps the pointer.
    sloppy_focus=0
    warp_cursor=0
    mouse_accel_profile=2
    mouse_accel_speed=0.2
    trackpad_accel_profile=2
    trackpad_accel_speed=0.2
    trackpad_natural_scrolling=1
    tap_to_click=1
    # clickfinger: a physical 2-finger press is RMB, 3-finger MMB.
    trackpad_click_method=2
    trackpad_disable_while_typing=0
    trackpad_scroll_factor=0.5
    # The DualSense touchpad is a ~40mm surface: flat accel and a hard
    # multiplier, as in mixins/hyprland.nix.
    device_rule=name:DualSense Wireless Controller Touchpad,accel_profile:1,accel_speed:0.7

    # Scroller: half-width columns, the four widths Mod+R cycles, a lone
    # column keeps its width, and focus scrolls only as far as needed
    # (Hyprland's focus_fit_method = 1).
    tag_rule=id:*,layout_name:scroller
    scroller_default_proportion=0.5
    scroller_proportion_preset=0.333,0.5,0.667,1.0
    scroller_ignore_proportion_single=0
    scroller_default_proportion_single=0.5
    scroller_prefer_overspread=0
    scroller_focus_center=0
    scroller_prefer_center=0
    # Every arrange fits the focused column inside the monitor, this far from
    # the edge, so Hyprland's Mod+C (fit_into_view) is always in effect and
    # has no bind here. 8 matches the outer gap Hyprland fitted to.
    scroller_structs=8

    # Decoration. Translucent windows on the dGPU only, so the blur has
    # something to show through; the e1504g's iGPU stays opaque.
    focused_opacity=${windowOpacity}
    unfocused_opacity=${windowOpacity}
    blur=1
    blur_layer=1
    blur_optimized=1
    blur_params_radius=8
    blur_params_num_passes=2
    # The quake console's backdrop (the special tag).
    special_dim=0.6
    enable_border_resize=1
    # XWayland renders at scale 1 instead of being upscaled on the 1.25 panel.
    xwayland_ignore_scale=1
    focus_on_activate=1

    # Animations. mango has beziers only: easeOutQuint stands in for the
    # Hyprland `glide` spring (~260ms, no visible overshoot), and tags slide
    # vertically like the stacked workspaces did.
    animations=1
    layer_animations=1
    animation_type_open=zoom
    animation_type_close=zoom
    zoom_initial_ratio=0.9
    zoom_end_ratio=0.9
    animation_fade_in=1
    animation_fade_out=1
    animation_duration_open=260
    animation_duration_move=260
    animation_duration_tag=260
    animation_duration_close=230
    animation_duration_focus=0
    animation_curve_open=0.22,1,0.36,1
    animation_curve_move=0.22,1,0.36,1
    animation_curve_tag=0.22,1,0.36,1
    animation_curve_close=0.4,0,0.2,1
    animation_curve_opacity_fade_in=0.4,0,0.2,1
    animation_curve_opacity_fade_out=0.4,0,0.2,1
    tag_animation_direction=0

    # Trackpad: three fingers sideways walk the tape, three fingers vertical
    # walk tags, both following the fingers while they move. Four fingers
    # open mango's overview, niri's gesture that Hyprland never had.
    gesture_live=1
    gesturebind=none,left,3,focusdir,right
    gesturebind=none,right,3,focusdir,left
    gesturebind=none,up,3,viewnext_have_client
    gesturebind=none,down,3,viewprev_have_client
    gesturebind=none,up,4,toggleoverview
    gesturebind=none,down,4,toggleoverview

    # Shell binds (FormalShell IPC). `l` also fires on the lock screen; `s`
    # matches the keysym, since the media keys share no keycode the es layout
    # names and mango would otherwise fold MicMute onto Mute.
    bind=SUPER,space,spawn,${fsIpc [ "menu" "toggle" ]}
    bind=SUPER,period,spawn,${fsIpc [ "menu" "summon" "emoji" ]}
    bind=SUPER,ntilde,spawn,${fsIpc [ "menu" "summon" "clipboard" ]}
    bind=SUPER,plus,spawn,${fsIpc [ "console" "toggle" ]}
    bind=SUPER+SHIFT,t,spawn,${fsBin} theme mode toggle
    bind=SUPER+SHIFT,Escape,spawn_shell,${fsIpc [ "lock" "lock" ]} && systemctl suspend
    binds=NONE,Print,spawn,${fsIpc [ "screenshot" "full" "default" ]}
    bind=SUPER+SHIFT,s,spawn,${fsIpc [ "screenshot" "pick" "smart" "default" ]}
    bindsl=NONE,XF86AudioRaiseVolume,spawn,${wpctl} set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 3%+
    bindsl=NONE,XF86AudioLowerVolume,spawn,${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 3%-
    binds=NONE,XF86AudioMute,spawn,${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle
    binds=NONE,XF86AudioMicMute,spawn,${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    bindsl=NONE,XF86MonBrightnessUp,spawn,${fsIpc [ "display" "brightnessStep" "5" ]}
    bindsl=NONE,XF86MonBrightnessDown,spawn,${fsIpc [ "display" "brightnessStep" "-5" ]}
    binds=NONE,XF86AudioPlay,spawn,${fsIpc [ "media" "playPause" ]}
    binds=NONE,XF86AudioPause,spawn,${fsIpc [ "media" "playPause" ]}
    binds=NONE,XF86AudioNext,spawn,${fsIpc [ "media" "next" ]}
    binds=NONE,XF86AudioPrev,spawn,${fsIpc [ "media" "previous" ]}

    # Alt-Tab: the shell's switcher; releasing Alt commits.
    bind=ALT,Tab,spawn,${fsIpc [ "switcher" "next" ]}
    bind=ALT+SHIFT,Tab,spawn,${fsIpc [ "switcher" "prev" ]}
    bindr=ALT,Alt_L,spawn,${fsIpc [ "switcher" "commit" ]}
    bindr=ALT,Alt_R,spawn,${fsIpc [ "switcher" "commit" ]}

    # Windows (the macOS/aerospace muscle memory, SUPER as mod)
    bind=SUPER,Return,spawn,ghostty
    # The Copilot key (Meta+Shift+F23) launches Claude at the nix config.
    bind=SUPER+SHIFT,F23,spawn,ghostty --working-directory=${config.home.homeDirectory}/.config/nix -e claude
    bind=SUPER,q,killclient
    bind=SUPER+SHIFT,f,togglefullscreen
    bind=SUPER,v,togglefloating
    bind=SUPER,b,spawn,helium

    # H/L walk columns, J/K walk windows stacked in a column; SHIFT moves.
    bind=SUPER,h,focusdir,left
    bind=SUPER,l,focusdir,right
    bind=SUPER,j,focusdir,down
    bind=SUPER,k,focusdir,up
    bind=SUPER+SHIFT,h,exchange_client,left
    bind=SUPER+SHIFT,l,exchange_client,right
    bind=SUPER+SHIFT,j,exchange_client,down
    bind=SUPER+SHIFT,k,exchange_client,up

    # Column width: F full width with gaps, M maximize to the edges, R cycles
    # the presets, minus narrows by ~10% of the desk monitor. Mod+plus is the
    # console above, which Hyprland also ran it alongside a widen.
    bind=SUPER,f,set_proportion,1.0
    bind=SUPER,m,togglemaximizescreen
    bind=SUPER,r,switch_proportion_preset
    bind=SUPER,minus,resizewin,-256,0
    # comma pulls the window into the column to its left (or out of its
    # stack), SHIFT+comma into the one on its right.
    bind=SUPER,comma,scroller_stack,left
    bind=SUPER+SHIFT,comma,scroller_stack,right

    # Tags by keycode, so the es layout's shifted number row cannot break the
    # SHIFT variants. Moving a window follows it, as on Hyprland.
    ${lib.concatMapStrings (i: ''
    bind=SUPER,code:${toString (i + 9)},${viewTag i}
    bind=SUPER+SHIFT,code:${toString (i + 9)},${moveTag i}
    '') (lib.range 1 9)}
    bind=SUPER,Tab,spawn,${mangoRules}/bin/mango-rules previous

    # MX Master 3S (modules/nixos/mixins/mouse.nix): thumb + wheel walks
    # tags, back/forward (XF86Tools/XF86Launch5 on the es layout) walk columns.
    axisbind=SUPER,DOWN,viewtoright_have_client
    axisbind=SUPER,UP,viewtoleft_have_client
    binds=NONE,XF86Tools,focusdir,left
    binds=NONE,XF86Launch5,focusdir,right
    mousebind=SUPER,btn_left,moveresize,curmove
    mousebind=SUPER,btn_right,moveresize,curresize

    # Window rules. Workspaces from mixins/wm-workspaces.nix, opened with focus.
    ${lib.concatMapStringsSep "\n" appRule workspaces.apps}
    # The quake console floats from its first frame, so the layout never
    # reflows under it before the shell places and parks it.
    window_rule=is_floating:1,app_id:^dev\.formalshell\.console$
    # Beeper (Electron) maps its main window floating; tile it.
    window_rule=is_floating:0,app_id:^([Bb]eeper)$
    # Minecraft's X11 grab drifts out of the window without a hard confine.
    window_rule=confine_pointer:1,app_id:^(Minecraft.*)$
    # Video PiP: floating on every tag, bottom-right, ~28% of the screen.
    window_rule=is_floating:1,is_global:1,width:0.28,height:0.28,offset_x:100,offset_y:100,title:^([Pp]icture[ -][Ii]n[ -][Pp]icture)$
    # Chromium's built-in notification (empty app-id and title): float,
    # every tag, top-right.
    window_rule=is_floating:1,is_global:1,offset_x:100,offset_y:-100,app_id:^$,title:^$
    # NativeDesktop popovers leave a transparent margin that blur would frost.
    window_rule=no_blur:1,app_id:^(nd-hello)$,title:^(nd-hello)$

    # Layers: the shell animates its own surfaces, so none of them get a
    # compositor animation on top. Namespaces are formalshell:<name>; the `.`
    # stands in for the colon, which the rule syntax splits on.
    layer_rule=no_animation:1,layer_name:^formalshell..*$
    ${lib.concatMapStringsSep "\n" (n: "layer_rule=no_blur:1,layer_name:^formalshell.${n}$") unblurredLayers}

    # uwsm waits on WAYLAND_DISPLAY in the user manager; mango imports it
    # itself, this adds the IPC socket the shell's mango backend reads.
    exec_once=uwsm finalize MANGO_INSTANCE_SIGNATURE
  '';

  # mango sits on wlroots, which takes WLR_DRM_DEVICES where Hyprland's
  # aquamarine took AQ_DRM_DEVICES (mixins/hyprland.nix has the reasoning).
  xdg.configFile."uwsm/env-mango" = lib.mkIf hasNvidia {
    text = ''
      export WLR_DRM_DEVICES="$(readlink -f /dev/dri/by-path/pci-0000:02:00.0-card)"
      export LIBVA_DRIVER_NAME=nvidia
      export NVD_BACKEND=direct
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export __GL_GSYNC_ALLOWED=1
    '';
  };

  systemd.user.services.mango-rules = {
    Unit = {
      Description = "Hyprland workspace semantics mango's config cannot express";
      ConditionEnvironment = "XDG_CURRENT_DESKTOP=mango";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${mangoRules}/bin/mango-rules";
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # mango has no workspace names, so the bar pills read them from here.
  programs.formalshell.settings.compositor.workspaceNames =
    map (i: workspaces.names.${toString i}) (lib.range 1 9);
}
