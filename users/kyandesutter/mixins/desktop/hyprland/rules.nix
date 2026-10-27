{ lib, useFormalshell, ... }:
''
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
  hl.layer_rule({ match = { namespace = "^(formalshell:frame)$" }, blur = true, ignore_alpha = 0.2, no_anim = true })
  hl.layer_rule({ match = { namespace = "^(formalshell:panel)$" }, blur = true, ignore_alpha = 0.2, no_anim = true })
  hl.layer_rule({ match = { namespace = "^(formalshell:notifications-center)$" }, blur = true, ignore_alpha = 0.2, no_anim = true })
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
  -- Opaque by design, so it takes the animation rule alone.
  hl.layer_rule({ match = { namespace = "^(formalshell:notifications)$" }, no_anim = true })
  ${lib.optionalString (!useFormalshell) ''
  -- Border colours: persist the last wallpaper palette across reloads
  -- DMS renders the live wallpaper-derived border colours to
  -- ~/.cache/dank/hypr-border.lua on every palette change and also pushes them
  -- live via `hyprctl eval` (see the matugen template in mixins/desktop/dms.nix). That
  -- eval is runtime-only, so a `hyprctl reload` (or the startup race before the
  -- first palette render) would drop back to the static Flexoki fallback in
  -- `general.col` in options.nix. Re-applying the cache file here on every config eval
  -- keeps the wallpaper colours instead. pcall: the file is absent before the
  -- first render: fall through to the fallback rather than erroring the whole
  -- config, which would leave the session unusable.
  --
  -- The formalshell arm reads its own palette in fsColors (chrome.nix) instead,
  -- and this file runs last, so a stale dank cache would otherwise win.
  pcall(dofile, os.getenv("HOME") .. "/.cache/dank/hypr-border.lua")''}
''
