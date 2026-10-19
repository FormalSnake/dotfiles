{ windowOpacity, ... }:
''
  -- General options
  hl.config({
    input = {
      kb_layout = "es",
      -- caps:escape: Caps Lock acts as Escape (no Caps Lock function).
      kb_options = "caps:escape",
      repeat_rate = 40,
      repeat_delay = 250,
      -- 2 = keyboard focus only changes on click (focus-follows-mouse off), but
      -- the hovered window still receives pointer events: so you can scroll an
      -- unfocused window under the cursor without it stealing keyboard focus.
      follow_mouse = 2,
      -- macOS-like feel: adaptive accel with a small positive speed gives the
      -- nonlinear, slightly-quicker pointer macOS uses.
      accel_profile = "adaptive",
      sensitivity = 0.2,
      touchpad = {
        -- clickfinger: a physical 2-finger press = RMB, 3-finger = MMB
        -- (replaces libinput's bottom-corner click areas). 2-finger tap
        -- already right-clicks via the default tap_to_click.
        natural_scroll = true,
        clickfinger_behavior = true,
        -- Keep the pad working while typing (moving the pointer or tapping
        -- mid-keystroke), libinput's palm detection still rejects a resting hand.
        disable_while_typing = false,
        -- Under 1 to tame libinput's over-sensitive two-finger scroll and land
        -- closer to macOS's pace, so it neither undershoots nor coasts past.
        scroll_factor = 0.5,
      },
    },
    general = {
      -- gaps_in is applied per window side, so it doubles between two tiled
      -- windows, while gaps_out lands once at the screen edge. 4/8 is what
      -- reads as a uniform 8px everywhere, the niri `gaps 8` geometry, and
      -- what metamorphosis publishes. Pantheon wears no screen frame and
      -- closes the outer gap to 6.
      gaps_in = fsChrome.gapsIn,
      gaps_out = fsChrome.gapsOut,
      border_size = 2,
      -- The scrolling tape (Hyprland 0.54+ has it in core, no plugin).
      layout = "scrolling",
      resize_on_border = true,
      -- The live wallpaper palette, or the static Flexoki fallback when the
      -- shell has not rendered one yet (see fsColors in chrome.nix). Without a
      -- value here Hyprland's built-in active border is white, which is what
      -- borders would revert to on every reload before the palette applies.
      col = {
        active_border = fsColor(fsChrome.borderColor),
        inactive_border = fsColors.border,
      },
    },
    -- Grouped (tabbed) windows carry their own border set, so they follow
    -- the same palette. Locked means the group refuses new members.
    group = {
      col = {
        border_active = fsColors.primary,
        border_inactive = fsColors.border,
        border_locked_active = fsColors.destructive,
      },
    },
    -- Scrolling tape behaviour. Deliberately close to niri's column model:
    -- half-width columns by default, the same four preset widths Mod+R cycles,
    -- and a lone column keeps its width (centered) instead of stretching to
    -- fill the screen. Flip fullscreen_on_one_column to true for the
    -- Omarchy-style "single window is always full screen" feel.
    scrolling = {
      column_width = 0.5,
      explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
      fullscreen_on_one_column = false,
      -- 1 = fit (scroll the minimum needed to reveal the focused column)
      -- rather than always re-centering it.
      focus_fit_method = 1,
      follow_focus = true,
    },
    -- Trackpad swipe feel (the gestures themselves are registered below).
    gestures = {
      -- A vertical swipe walks past the neighbouring workspace instead of
      -- clamping to it, so one long swipe crosses the stack the way niri's
      -- does. workspace_swipe_invert stays at its default true: that is the
      -- direction where the workspaces follow the fingers.
      workspace_swipe_forever = true,
      scrolling = {
        -- Snapping the pointer into the newly focused window is Hyprland's
        -- default; niri leaves it where you put it, and with follow_mouse = 2
        -- a warped pointer only means the next hover lands somewhere you
        -- didn't aim at.
        move_snap_cursor = false,
      },
    },
    decoration = {
      rounding = fsChrome.rounding,
      -- The window shadow the shell's theme asks for (fsChrome in chrome.nix):
      -- elementary's cast under pantheon, off under metamorphosis, which
      -- also turns off the shadow Hyprland enables by default.
      shadow = {
        enabled = fsChrome.shadow,
        range = fsChrome.shadowRange,
        render_power = fsChrome.shadowPower,
        offset = fsChrome.shadowOffset,
        color = fsColor(fsChrome.shadowColor),
        color_inactive = fsColor(fsChrome.shadowInactiveColor),
      },
      -- Separates the quake console from the workspace it drops over. Only
      -- applies while a special workspace is on screen, so it costs the
      -- rest of the session nothing, and the console is the only special
      -- workspace here.
      dim_special = 0.6,
      -- Ever-so-slight transparency on every window, active and inactive
      -- alike, so the backdrop blur below has something to show through
      -- (dGPU hosts only, see windowOpacity).
      active_opacity = ${windowOpacity},
      inactive_opacity = ${windowOpacity},
      blur = {
        enabled = fsChrome.blur,
        size = 8,
        passes = 2,
        new_optimizations = true,
      },
    },
    animations = { enabled = true },
    misc = {
      disable_hyprland_logo = true,
      disable_splash_rendering = true,
      -- When an app opens a link, the browser requests focus via
      -- xdg-activation. Hyprland ignores activation requests by default
      -- (anti-focus-steal), so the link would open with the browser left in
      -- the background. Honour the request instead.
      focus_on_activate = true,
      anr_missed_pings = 3,
      -- Default off for outputs without a rule; the g815 pair pins vrr = 3
      -- in its monitor rules in outputs.nix.
      vrr = 0,
    },
    render = {
      direct_scanout = 1,
      -- Auto-HDR: the desktop stays SDR/8-bit at all times; when a fullscreen
      -- app requests an HDR swapchain, Hyprland flips that output to HDR for
      -- the duration and reverts on exit. 1 = generic BT.2020+PQ; bump to 2
      -- (hdredid, uses the panel's EDID primaries) if HDR colours look off.
      cm_auto_hdr = 1,
    },
    -- The panel runs at fractional scale (1.25) on the g815. XWayland can't do
    -- fractional scaling, so Hyprland upscales X11 surfaces → blurry output
    -- and per-frame upscale overhead. force_zero_scaling makes XWayland render
    -- at scale 1 (crisp, native rate); X11 apps that look small can be nudged
    -- with GDK_SCALE / per-app DPI. No-op on the 1x hosts.
    xwayland = {
      force_zero_scaling = true,
    },
  })

  -- The DualSense touchpad lands in Hyprland's Mouse list, not the touchpad
  -- list, so it inherits the global sensitivity meant for a full-size mouse.
  -- That surface is about 40mm wide, so 0.2 with adaptive accel means a lot
  -- of finger for very little pointer, and slow moves get damped on top of
  -- it. Flat accel plus a hard multiplier makes travel proportional. The
  -- Bluetooth link still costs ~20ms that no setting here can remove; USB
  -- does not have it.
  hl.device({
    name = "dualsense-wireless-controller-touchpad",
    accel_profile = "flat",
    sensitivity = 0.7,
  })

  -- Animations: spring physics for anything that moves
  -- The old `snappy` bezier put 75% of the distance into the first 15% of the
  -- duration. That fast part is too quick to read as travel, so the only
  -- motion actually perceived was the shallow tail, which is why everything
  -- looked linear. A spring starts from rest, accelerates, then decelerates
  -- into the target, so the whole path is legible.
  -- At mass 1: zeta = dampening / (2 * sqrt(stiffness)) sets the bounce and
  -- settle time is roughly 4.6 / (zeta * sqrt(stiffness)). `glide` is zeta
  -- 0.85 (~1% overshoot, ~255ms), `firm` is critically damped (no bounce,
  -- ~230ms). A spring derives its duration from those numbers and ignores
  -- `speed`, but hl.animation still rejects the call without one, so each
  -- spring leaf carries the speed matching its settle time.
  hl.curve("glide", { type = "spring", mass = 1, stiffness = 450, dampening = 36 })
  hl.curve("firm",  { type = "spring", mass = 1, stiffness = 400, dampening = 40 })
  -- Opacity and border colour must not overshoot, so they stay on a bezier.
  -- Durations are in ds (1 ds = 100ms).
  hl.curve("eased", { type = "bezier", points = { { 0.4, 0 }, { 0.2, 1 } } })

  -- Workspaces slide vertically, matching niri's stacked-workspace model:
  -- switching pushes the next one up or down.
  hl.animation({ leaf = "windows",          enabled = true, spring = "glide", speed = 2.6 })
  hl.animation({ leaf = "windowsOut",       enabled = true, spring = "firm",  speed = 2.3, style = "popin 90%" })
  hl.animation({ leaf = "layers",           enabled = true, spring = "firm",  speed = 2.3 })
  hl.animation({ leaf = "fade",             enabled = true, bezier = "eased", speed = 2.5 })
  hl.animation({ leaf = "border",           enabled = true, bezier = "eased", speed = 5 })
  hl.animation({ leaf = "workspaces",       enabled = true, spring = "glide", speed = 2.6, style = "slidevert" })
  hl.animation({ leaf = "specialWorkspace", enabled = true, spring = "glide", speed = 2.6, style = "slidevert" })

  -- Trackpad gestures (niri's set, 1:1 under the fingers)
  -- Horizontal scrolls the tape, vertical walks workspaces: the same split
  -- niri had, and the one the tape/stack geometry implies. `scroll_move` is
  -- the scrolling layout's own gesture (0.56+): it drags the tape 1:1, then
  -- projects the release velocity and snaps to a column, so a flick carries.
  -- Both stay on 3 fingers: niri's four-finger overview swipe has no
  -- equivalent, Hyprland has no overview. A directional ("up") gesture would
  -- shadow the vertical one over half the axis, which is why fullscreen went
  -- keyboard-only (Mod+Shift+F).
  hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })
  hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })
''
