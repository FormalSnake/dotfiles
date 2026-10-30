-- Window colours
-- FormalShell's ThemeEngine renders the live wallpaper palette to
-- ~/.config/hypr/formalshell-colors.lua on every wallpaper and mode change
-- and then calls `hyprctl reload`, which is what re-runs this file and
-- picks the new table up: a dofile'd file is not a source'd one, so
-- Hyprland never watches it. The literals below are the static Flexoki
-- fallback for the window before the shell's first render, and for a
-- session running the other shell. pcall because a missing or malformed
-- file would otherwise abort this whole config and leave the session
-- unusable.
local fsColors = {
  primary = "rgb(4385BE)",
  border = "rgb(575653)",
  destructive = "rgb(D14D41)",
}
do
  local ok, loaded = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/formalshell-colors.lua")
  if ok and type(loaded) == "table" then
    for key in pairs(fsColors) do
      if type(loaded[key]) == "string" then fsColors[key] = loaded[key] end
    end
  end
end

-- Window chrome
-- The shell's theme table decides the rounding, the blur, the frame colour
-- and the window shadow (elementary's under the pantheon preset, none under
-- metamorphosis) and publishes them to
-- ~/.config/hypr/formalshell-chrome.lua beside the colours, same dofile,
-- same reload. The literals are the metamorphosis defaults for a session
-- before the shell's first render. A colour is either an rgba literal or
-- the name of a role in fsColors.
local fsChrome = {
  rounding = 10,
  blur = true,
  gapsIn = 4,
  gapsOut = 8,
  borderColor = "primary",
  shadow = false,
  shadowRange = 4,
  shadowPower = 3,
  shadowOffset = { 0, 0 },
  shadowColor = "rgba(000000ed)",
  shadowInactiveColor = "rgba(000000ed)",
}
do
  local ok, loaded = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/formalshell-chrome.lua")
  if ok and type(loaded) == "table" then
    for key in pairs(fsChrome) do
      if loaded[key] ~= nil and type(loaded[key]) == type(fsChrome[key]) then fsChrome[key] = loaded[key] end
    end
  end
end
local function fsColor(c) return fsColors[c] or c end

-- Per-host layout: monitors, which workspaces sit on which output, window opacity, direct
-- scanout and GPU environment. host.lua comes from fspec's <host>/home overlay and returns a table with any of
-- these keys; without it the internal panel is all there is.
local host = {
  monitors = { { output = "eDP-1", mode = "preferred", position = "auto", scale = 1.0 } },
  workspaces = {},
  opacity = 1.0,
  direct_scanout = 1,
  env = {},
}
do
  local ok, loaded = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/host.lua")
  if ok and type(loaded) == "table" then
    for key, value in pairs(loaded) do host[key] = value end
  end
end

-- Monitors
for _, m in ipairs(host.monitors) do hl.monitor(m) end

-- Catch-all: any other external display at its highest refresh rate
-- ("highrr" forces the panel's max, unlike "preferred" which is usually
-- 60Hz), placed to the right of whatever precedes it.
hl.monitor({ output = "", mode = "highrr", position = "auto", scale = 1.0 })

-- Variables
local mod = "SUPER"        -- primary modifier (the physical Cmd-position key)
local terminal = "ghostty"

-- Workspaces
-- Nine named workspaces mirroring the macOS/aerospace assignment. The name
-- is what the bar renders on each pill, binds and window rules address the
-- numeric id.
local wsName = { " web", " term", " dev", " chat", " prod", " print", "󰚩 ai", " media", " game" }

for i = 1, 9 do
  local rule = { workspace = tostring(i), default_name = wsName[i] }
  for key, value in pairs(host.workspaces[i] or {}) do rule[key] = value end
  hl.workspace_rule(rule)
end


-- Environment
-- Cursor theme/size for XWayland (X11) clients: without XCURSOR_THEME they
-- fall back to a default theme and show a *different* cursor than native
-- Wayland apps (which read it from home.pointerCursor in session.nix).
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
-- Qt platform theme (qt6ct) so Qt apps follow the shell's palette (see the
-- qt6ct notes in mixins/desktop/qt.nix); QS_ICON_THEME is the Quickshell-specific
-- icon override kept for Qt tooling. Also exported from uwsm/env in session.nix, so
-- systemd user services (which do NOT inherit Hyprland's environment) get
-- them too.
hl.env("QS_ICON_THEME", "Colloid-Dark")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
for key, value in pairs(host.env) do hl.env(key, value) end


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
    active_opacity = host.opacity,
    inactive_opacity = host.opacity,
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
    -- Black under everything, so the session arrives out of the greeter's
    -- black (FormalShell's docs/superpowers/specs/2026-10-30-seams.md).
    background_color = "rgb(000000)",
    -- When an app opens a link, the browser requests focus via
    -- xdg-activation. Hyprland ignores activation requests by default
    -- (anti-focus-steal), so the link would open with the browser left in
    -- the background. Honour the request instead.
    focus_on_activate = true,
    anr_missed_pings = 3,
    -- FormalShell restarted while locked (an apply, a crash) takes the lock
    -- back instead of leaving Hyprland's dead-locker screen.
    allow_session_lock_restore = true,
    -- Default off for outputs without a rule; the g815 pair pins vrr = 3
    -- in its monitor rules in outputs.nix.
    vrr = 0,
  },
  render = {
    direct_scanout = host.direct_scanout,
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

-- The pointer stays hidden until the shell has faded the desktop in. Hidden
-- twice over: Hyprland draws it for its first frames whatever
-- `cursor.invisible` says, so its cursor manager starts on a theme of
-- transparent cursors too. That reads XCURSOR_THEME once at start, so the
-- variable goes back to the real theme for everything started after it. The
-- shell then writes its marker for this instance and calls
-- formalshell_arrived, which puts the real theme on the pointer and shows it,
-- so a reload after that (the shell's own after each publish) leaves it
-- shown. A shell that never starts gets it back ten seconds in, marker and all.
local blank = "formalos-blank"
local function real_cursor_theme()
  local theme = os.getenv("XCURSOR_THEME") or "default"
  if theme == blank then
    theme = os.getenv("FORMALSHELL_XCURSOR_THEME") or "default"
  end
  return theme
end
function formalshell_arrived()
  local theme = real_cursor_theme()
  hl.env("XCURSOR_THEME", theme)
  hl.exec_cmd("hyprctl setcursor " .. theme .. " " .. (os.getenv("XCURSOR_SIZE") or "24"))
  hl.config({ cursor = { invisible = false } })
end
local arrived = (os.getenv("XDG_RUNTIME_DIR") or "") .. "/formalshell/arrived-" .. (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "")
local marker = io.open(arrived, "r")
local arriving = not marker
if marker then
  marker:close()
end
-- Called again after any later file that sets XCURSOR_THEME itself (the
-- installer's entry does, after hypr-user.lua). Only before the start: a
-- reload after it would hand the blank theme to whatever starts next.
function formalshell_blank_cursor()
  if arriving and not os.getenv("FORMALSHELL_CURSOR_STARTED") then
    hl.env("FORMALSHELL_XCURSOR_THEME", real_cursor_theme())
    hl.env("XCURSOR_THEME", blank)
  end
end
if arriving then
  -- One transparent pixel, as an Xcursor file, under every name Hyprland asks for at start.
  local dir = (os.getenv("HOME") or "") .. "/.local/share/icons/" .. blank .. "/cursors/"
  os.execute("mkdir -p '" .. dir .. "'")
  for _, name in ipairs({ "default", "left_ptr", "arrow", "top_left_arrow", "wait", "watch", "progress", "left_ptr_watch", "text", "xterm", "pointer", "hand2" }) do
    local f = io.open(dir .. name, "wb")
    if f then
      f:write("Xcur\16\0\0\0\0\0\1\0\1\0\0\0\2\0\253\255\24\0\0\0\28\0\0\0$\0\0\0\2\0\253\255\24\0\0\0\1\0\0\0\1\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0")
      f:close()
    end
  end
  formalshell_blank_cursor()
  hl.config({ cursor = { invisible = true } })
  hl.on("hyprland.start", function()
    hl.env("FORMALSHELL_CURSOR_STARTED", "1")
    hl.env("XCURSOR_THEME", real_cursor_theme())
  end)
end
hl.on("hyprland.start", function()
  hl.exec_cmd([==[sleep 10 && mkdir -p "$XDG_RUNTIME_DIR/formalshell" && touch "$XDG_RUNTIME_DIR/formalshell/arrived-$HYPRLAND_INSTANCE_SIGNATURE" && hyprctl eval 'formalshell_arrived()']==])
end)

-- Keybinds (mirror the macOS/aerospace muscle memory, SUPER as mod)
-- FormalShell IPC. `menu toggle` is the no-argument verb M13 added for
-- exactly this bind: root summon when closed, close when already open.
hl.bind(mod .. " + Space", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call menu toggle"))
-- Emoji picker (M12): the menu's emoji route, same muscle memory as
-- DMS's spotlight :e trigger. Enter copies the pick, the clipboard
-- service captures it.
hl.bind(mod .. " + period", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call menu summon emoji"))
-- ñ is a dedicated key on the es layout; its XKB keysym is `ntilde`.
hl.bind(mod .. " + ntilde", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call menu summon clipboard"))
-- Quake console (FormalShell M37): one ghostty that drops over whatever
-- workspace you are on and parks on Hyprland's special:formalshell-console
-- when toggled off, session intact. The shell spawns it from
-- console.command; nothing here needs a window rule, since it places the
-- window itself on every show. `+` is unshifted on the es layout.
hl.bind(mod .. " + plus", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call console toggle"))
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell theme mode toggle"))
-- Sleep: lock then suspend on demand, so resume lands on the lock screen
-- (exec_cmd runs through sh -c).
-- Logout through the shell, which fades the desktop to black and then exits Hyprland.
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call power logout"))
hl.bind(mod .. " + SHIFT + Escape", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call lock lock && systemctl suspend"))

-- Screenshots via the shell (M12 screenshot IPC target: grim/slurp on the
-- wrapper PATH, saves to screenshot.directory and wl-copy's the image,
-- success lands as a shell notification). Owner rule: when the shell has
-- the feature, prefer it over the compositor's built-in: it's WM-agnostic,
-- so the binds survive compositor changes. Print = whole screen,
-- Mod+Shift+S = the capture picker (macOS Cmd+Shift+5): a toolbar of
-- three shot and three record modes, digits 1-6 to switch between them,
-- Tab and the arrows to cycle windows, Return to commit. `screenshot
-- region` is the older bare-slurp route with no toolbar and no
-- recording at all, so it is deliberately not bound here.
hl.bind("Print", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call screenshot full default"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call screenshot pick smart default"))

-- Volume via wpctl: FormalShell's AudioService tracks PipeWire directly
-- and auto-shows the volume OSD on any external change, so the keys don't
-- need to route through the shell. Brightness does: the shell steps the
-- focused output (backlight or DDC) through one writer per device and
-- shows the OSD itself. Media routes through the shell's active MPRIS
-- player.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("/usr/bin/wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 3%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("/usr/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("/usr/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("/usr/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call display brightnessStep 5"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call display brightnessStep -5"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call media playPause"))
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call media playPause"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call media next"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call media previous"))


hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
-- Reclaim the laptop's Copilot key: it launches Claude, not Copilot.
-- Microsoft's spec (which ASUS honours) has the key emit Meta+Shift+F23;
-- this drops a fresh local ghostty into `claude`, cwd'd at the nix config.
hl.bind(mod .. " + SHIFT + F23", hl.dsp.exec_cmd("ghostty --working-directory=/home/kyandesutter/.config/formalspec -e claude"))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }))
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + B", hl.dsp.exec_cmd("/opt/fspec/current/bin/helium"))

-- Vim-style focus/move (aerospace alt-hjkl), mapped onto the scrolling
-- tape's column model: H/L walk columns (layout-aware, so they wrap and
-- scroll the tape rather than jumping to a neighbouring monitor), J/K walk
-- windows stacked inside the focused column.
hl.bind(mod .. " + H", hl.dsp.layout("focus l"))
hl.bind(mod .. " + L", hl.dsp.layout("focus r"))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "d" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + SHIFT + H", hl.dsp.layout("swapcol l"))
hl.bind(mod .. " + SHIFT + L", hl.dsp.layout("swapcol r"))
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.swap({ direction = "d" }))
hl.bind(mod .. " + SHIFT + K", hl.dsp.window.swap({ direction = "u" }))

-- Column width. F = full width with gaps (niri's maximize-column), M = true
-- maximize to the edges, R = cycle the explicit_column_widths presets,
-- minus/plus = ±10%.
hl.bind(mod .. " + F", hl.dsp.layout("colresize 1.0"))
hl.bind(mod .. " + M", hl.dsp.window.fullscreen({ action = "toggle", mode = "maximized" }))
hl.bind(mod .. " + R", hl.dsp.layout("colresize +conf"))
hl.bind(mod .. " + minus", hl.dsp.layout("colresize -0.1"))
hl.bind(mod .. " + plus", hl.dsp.layout("colresize +0.1"))

-- Tape housekeeping: C scrolls the focused column fully into view; comma
-- pulls the focused window into the previous column (or expels it back out
-- if it isn't alone), SHIFT+comma does the same against the next column.
hl.bind(mod .. " + C", hl.dsp.layout("fit_into_view"))
hl.bind(mod .. " + comma", hl.dsp.layout("consume_or_expel prev"))
hl.bind(mod .. " + SHIFT + comma", hl.dsp.layout("consume_or_expel next"))

-- Workspaces by id, addressed as `code:N` (keycodes, not keysyms) so the
-- es layout's shifted number row can't break the SHIFT variants.
for i = 1, 9 do
  hl.bind(mod .. " + code:" .. (i + 9), hl.dsp.focus({ workspace = tostring(i) }))
  hl.bind(mod .. " + SHIFT + code:" .. (i + 9), hl.dsp.window.move({ workspace = tostring(i), follow = true }))
end

hl.bind(mod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))

-- Alt-Tab. Hyprland has no most-recently-used hold-and-cycle switcher
-- (niri's `recent-windows`). Under FormalShell the shell draws one
-- (Gala's, under the pantheon preset; the IPC refuses under any other
-- theme and the keys then do nothing): each press steps the card,
-- SHIFT reverses, releasing Alt commits. Under DMS this is a plain stack
-- cycle. Alt+grave (cycle windows of the same app) has no equivalent
-- and is dropped.
hl.bind("ALT + Tab", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call switcher next"), { repeating = true })
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call switcher prev"), { repeating = true })
-- `transparent`: Hyprland shadows a bind whose key is still held when
-- another bind consumes a press (KeybindManager.cpp, shadowKeybinds), so
-- a plain release bind on Alt never fires after an Alt+Tab; a
-- transparent one is skipped by the shadowing.
hl.bind("ALT + Alt_L", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call switcher commit"), { release = true, transparent = true })
hl.bind("ALT + Alt_R", hl.dsp.exec_cmd("/opt/fspec/current/bin/formalshell ipc --any-display call switcher commit"), { release = true, transparent = true })

-- MX Master 3S, usable without the keyboard. Its three thumb buttons are
-- remapped to keys in modules/nixos/mixins/hardware/mouse.nix: the gesture button is
-- Mod, so thumb + main wheel walks workspaces, and back/forward arrive as
-- KEY_F13/KEY_F14 and walk columns. Binds match keysyms, not keycodes, and
-- the es layout gives those two XF86Tools and XF86Launch5 (it has no F13/F14
-- keysym at all). Check with
-- `xkbcli compile-keymap --layout es | rg 'key <FK1[34]>'` before touching
-- either half.
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("XF86Tools", hl.dsp.layout("focus l"))
hl.bind("XF86Launch5", hl.dsp.layout("focus r"))

-- Mouse drag/resize (aerospace SUPER+LMB move, SUPER+RMB resize).
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Window → workspace rules (Linux app classes; Hyprland matches `class`)
-- No `silent`: when one of these apps opens, Hyprland follows the window to
-- its assigned workspace. No terminal rule: ghostty opens where you are.
hl.window_rule({ match = { class = "^([Hh]elium)$" }, workspace = "1" })
hl.window_rule({ match = { class = "^([Cc]ode|[Zz]ed|dev.zed.Zed)$" }, workspace = "3" })
hl.window_rule({ match = { class = "^([Ss]lack|WhatsApp|discord|[Bb]eeper|de.schmidhuberj.Flare)$" }, workspace = "4" })
-- Messages (GPUI) sets no Wayland app-id, so its rule matches the title.
hl.window_rule({ match = { title = "^(Messages)$" }, workspace = "4" })
-- Beeper (Electron) maps its main window floating, so it never tiles.
-- Force it back into the layout.
hl.window_rule({ match = { class = "^([Bb]eeper)$" }, float = false })
-- Sushi sizes itself to the previewed content, so it floats centred like
-- Quick Look instead of tiling into the layout.
hl.window_rule({ match = { class = "^(org.gnome.NautilusPreviewer)$" },
  float = true, center = true })
-- The quake console maps straight onto its own special workspace,
-- floating, without ever touching the layout you are looking at. The
-- shell sizes and reveals it afterwards either way, but without this
-- rule the terminal tiles into the current workspace for the frames
-- before that lands, and the layout reflows twice for nothing.
hl.window_rule({
  match = { class = "^(dev.formalshell.console)$" },
  workspace = "special:formalshell-console silent",
  float = true,
})
hl.window_rule({ match = { class = "^([Oo]bsidian)$" }, workspace = "5" })
hl.window_rule({ match = { class = "^([Cc]laude)$" }, workspace = "7" })
hl.window_rule({ match = { class = "^([Kk]opuz)$" }, workspace = "8" })
hl.window_rule({ match = { class = "^(dev.formalsnake.formalmusic)$" }, workspace = "8" })
-- Sober sends no content type, so vrr = 3 outputs never switch VRR on for it.
hl.window_rule({ match = { class = "^(org.vinegarhq.Sober)$" }, content = "game" })
-- YouTube Music web app (mixins/desktop/webapps.nix). Chromium names a shared-profile
-- --app window after its URL and profile, not the launcher's --class.
hl.window_rule({ match = { class = "^(chrome-music.youtube.com__-Default)$" }, workspace = "8" })
-- Minecraft locks the pointer with an X11 grab plus a recentering warp,
-- which Hyprland does not hold the way it holds a Wayland pointer
-- constraint: the cursor drifts out of the window, and the warp back on
-- re-grab arrives as a mouse-look delta, so a stray click spins the camera.
-- Matched by class rather than the wiki's `content = "game"`, which
-- XWayland clients never set, and it applies windowed as well as fullscreen.
hl.window_rule({ match = { class = "^(Minecraft.*)$" }, confine_pointer = true })

--: Chromium/helium auxiliary popups: float, pin across every workspace, and
--   tuck into a corner. `pin` is Hyprland's "show on all workspaces": niri
--   had no equivalent, so these used to just float. helium gives these three
--   windows distinct identities, captured live with `hyprctl clients`:
--     • Video PiP      → class "" (empty), title "Picture in picture"
--     • Built-in notif → class "" (empty), title "" (empty)
--     • Document PiP   → class "helium", maps floating, dynamic page title
--   Matching is on creation-time class/title, which is why a
--   `title:Picture-in-Picture` rule never fires: the real title is
--   "Picture in picture" (spaces, not hyphens) and the class is empty.
--
-- Video PiP → float, pin, bottom-right, capped to ~28% (it opens ~1240px wide).
hl.window_rule({ match = { title = "^([Pp]icture[ -][Ii]n[ -][Pp]icture)$" },
  float = true, pin = true,
  size = { "(monitor_w*0.28)", "(monitor_h*0.28)" },
  move = { "(monitor_w-window_w-16)", "(monitor_h-window_h-16)" } })
-- Document PiP (and any other floating helium popup) → pin + sane size
-- (Meet's document PiP opens ~1240x1110) + bottom-right. Matched on floating
-- state, so normal *tiled* browser windows are untouched.
hl.window_rule({ match = { class = "^(helium)$", float = true },
  pin = true,
  size = { "(monitor_w*0.28)", "(monitor_h*0.28)" },
  move = { "(monitor_w-window_w-16)", "(monitor_h-window_h-16)" } })
-- Chrome built-in notification → empty class AND empty title. Float (it
-- tiles otherwise: a calendar alert wrecking the layout), pin, top-right.
-- The empty title is what sets it apart from the video PiP above.
hl.window_rule({ match = { class = "^$", title = "^$" },
  float = true, pin = true,
  move = { "(monitor_w-window_w-16)", "16" } })

-- NativeDesktop browser popovers (nd-hello) leave a transparent margin
-- around the shadow, rounded corners, and arrow. Hyprland blurs into that
-- margin, which shows as a frosted box. Popups are floating XWayland
-- windows with class and title "nd-hello"; the main window shares the
-- class but tiles with the page title, so xwayland+float excludes it.
hl.window_rule({
  match = { class = "^(nd-hello)$", title = "^(nd-hello)$", xwayland = true, float = true },
  no_blur = true,
})

-- Blur behind the shell's own layer surfaces: FormalShell paints its cards
-- at theme.surfaceOpacity, so the blur under them is what shows through.
-- ignore_alpha 0.2 keeps the fully transparent gaps in the bar unblurred.
-- no_anim throughout: the shell animates its own surfaces (DESIGN.md §1
-- Motion), so a compositor animation on the layer runs a second one over
-- the top of it (the toast stack's resize against Hyprland's `layers`
-- spring).
hl.layer_rule({ match = { namespace = "^(formalshell:bar)$" }, blur = true, ignore_alpha = 0.2, no_anim = true })
hl.layer_rule({ match = { namespace = "^(formalshell:panel)$" }, blur = true, ignore_alpha = 0.2, no_anim = true })
hl.layer_rule({ match = { namespace = "^(formalshell:tooltip)$" }, blur = true, ignore_alpha = 0.2, no_anim = true })
hl.layer_rule({ match = { namespace = "^(formalshell:osd)$" }, blur = true, ignore_alpha = 0.2, no_anim = true })
-- The window switcher draws its card at 0.6, so without the blur under
-- it the card reads as see-through rather than as frosted.
hl.layer_rule({ match = { namespace = "^(formalshell:switcher)$" }, blur = true, ignore_alpha = 0.2, no_anim = true })
-- The modal layers cover the whole output with a 0.5 scrim. ignore_alpha
-- 0.6 leaves the scrim under the blur, so it only darkens the desktop, and
-- keeps the card over it (theme.surfaceOpacity, 0.85) blurred.
hl.layer_rule({ match = { namespace = "^(formalshell:menu)$" }, blur = true, ignore_alpha = 0.6, no_anim = true })
hl.layer_rule({ match = { namespace = "^(formalshell:polkit)$" }, blur = true, ignore_alpha = 0.6, no_anim = true })
hl.layer_rule({ match = { namespace = "^(formalshell:plugin-overlay)$" }, blur = true, ignore_alpha = 0.6, no_anim = true })
hl.layer_rule({ match = { namespace = "^(formalshell:radio)$" }, blur = true, ignore_alpha = 0.6, no_anim = true })
-- The toast cards are drawn at surfaceOpacity too; the clear layer between
-- them falls under the 0.2 mark.
hl.layer_rule({ match = { namespace = "^(formalshell:notifications)$" }, blur = true, ignore_alpha = 0.2, no_anim = true })
-- The arrival and departure veil fades itself.
hl.layer_rule({ match = { namespace = "^(formalshell:veil)$" }, no_anim = true })

