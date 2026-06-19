# Hyprland 0.55 Lua config — findings

**Hyprland 0.55 replaced the hyprlang `.conf` config with Lua.** This is a hard breaking
change, not a deprecation with a fallback:

- File moved: `~/.config/hypr/hyprland.conf` → `~/.config/hypr/hyprland.lua`.
- Language changed: hyprlang (INI-style `option = value`, `$var`, `bind = …`) → **Lua**,
  driven by a `hl` global namespace.
- The old hyprlang docs live on the **0.54 wiki**; everything below is **0.55+**.

Symptom when you feed hyprlang to the new parser: `hyprland.lua:N: <name> expected near '$'`
— it's a Lua syntax error on the first hyprlang `$variable` line. That's what broke the g815.

## How this repo handles it

home-manager's `wayland.windowManager.hyprland.settings` **only serializes the old hyprlang
syntax** — there is no Lua generator yet. Using it under Hyprland 0.55 writes invalid Lua and
the session dies.

Workaround used in `users/kyandesutter/mixins/hyprland.nix`:

- **Do not** use `wayland.windowManager.hyprland` (its serializer emits hyprlang).
- Write the file directly: `xdg.configFile."hypr/hyprland.lua".text = '' … lua … ''`.
- System-side Hyprland (`programs.hyprland`, portals, greetd, uwsm session) is unaffected —
  it lives in `modules/nixos/mixins/hyprland.nix` and the config language is independent of it.

Nix `''` strings: safe here because the Lua contains no `${…}` (the dangerous sequence).
`$(slurp)` and `@DEFAULT_AUDIO_SINK@` pass through untouched. Verify any future edit with
`luac -p` on the evaluated text before rebuilding.

**Gotcha on first switch:** if a *real* `~/.config/hypr/hyprland.lua` already exists (not an
HM symlink), activation aborts with "would be clobbered". `rm ~/.config/hypr/hyprland.lua`
and rebuild again.

## Lua API reference (the bits this config uses)

Top-level functions:

| Function | Purpose |
| --- | --- |
| `hl.config({ category = { opt = val } })` | General options: `general`, `decoration`, `input`, `misc`, `animations`. Callable multiple times; later calls update individual values. |
| `hl.monitor({ output, mode, position, scale })` | One call per monitor. `output=""` is the catch-all/default. |
| `hl.env(name, value)` | Environment variable (replaces hyprlang `env = NAME,VALUE`). |
| `hl.on("hyprland.start", fn)` | Run `fn` at startup (replaces `exec-once`). Use `hl.exec_cmd(...)` inside. |
| `hl.exec_cmd(cmd, rules?)` | Run a shell command; optional `rules` table (e.g. `{ workspace = "1", float = true }`). |
| `hl.bind(keys, dispatcher, opts?)` | Keybind. `keys` = `"SUPER + SHIFT + Q"`. `opts` = `{ repeating = true }` (held-repeat, old `bindel`) or `{ mouse = true }` (old `bindm`). |
| `hl.window_rule({ match = {…}, <effects> })` | Window rule. `match` keys: `class`, `title`, `float`, `workspace` (regex strings). Effects mirror option names, e.g. `workspace = "1 silent"`, `float = true`, `border_color`, `opacity`, `rounding`, `stay_focused`. |
| `hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0 })` | Per-workspace rule. |
| `hl.define_submap(name, fn)` | Submap; bind `hl.dsp.submap("reset")` to leave. |
| `require("dir/file")` or `require("dir.file")` | Split config across Lua files under `$XDG_CONFIG_HOME/hypr`. |
| `hl.dispatch(dsp)` | Run a dispatcher imperatively (inside a Lua function bind). |
| `hl.get_active_window()` / `hl.get_config("animations.enabled")` | Introspection for scripted binds. |

Dispatchers (`hl.dsp.*`) — pass the **result** to `hl.bind`, or to `hl.dispatch` inside a function:

| Dispatcher | Old hyprlang | Notes |
| --- | --- | --- |
| `hl.dsp.exec_cmd(cmd, rules?)` | `exec` | |
| `hl.dsp.window.close(window?)` | `killactive` | graceful close |
| `hl.dsp.window.kill(window?)` | `forcekillactive` | hard kill the owning process |
| `hl.dsp.window.fullscreen({ mode?, action?, window? })` | `fullscreen` | `mode` = `"fullscreen"`/`"maximized"`; `action` = `"toggle"`/`"set"` |
| `hl.dsp.window.float({ action?, window? })` | `togglefloating` | `action` = `"toggle"`/`"set"` |
| `hl.dsp.focus({ direction })` | `movefocus` | `direction` = `l`/`r`/`u`/`d` |
| `hl.dsp.focus({ workspace, on_current_monitor? })` | `workspace` | switch workspace; `workspace` accepts a number, `"previous"`, `"special:x"`, … |
| `hl.dsp.window.move({ direction, group_aware? })` | `movewindow` | move active window by direction |
| `hl.dsp.window.move({ workspace, follow? })` | `movetoworkspace` / `movetoworkspacesilent` | `follow = true` follows the window (= `movetoworkspace`); omit/false = silent |
| `hl.dsp.window.drag()` | `movewindow` (mouse) | use with `{ mouse = true }` |
| `hl.dsp.window.resize()` / `({ x, y, relative })` | `resizewindow` / `resizeactive` | mouse form vs. fixed-step form |
| `hl.dsp.workspace.toggle_special(name)` | `togglespecialworkspace` | |
| `hl.dsp.submap(name)` | `submap` | |
| `hl.dsp.global(string)` | `global` | dbus global shortcut (e.g. `alttab:next`) |

## Migration cheatsheet (hyprlang → Lua)

```lua
-- monitor = eDP-1, 2560x1600@240, 0x0, 1.25
hl.monitor({ output = "eDP-1", mode = "2560x1600@240", position = "0x0", scale = 1.25 })
-- monitor = , preferred, auto, 1.0
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.0 })

-- $mod = SUPER
local mod = "SUPER"

-- env = XCURSOR_SIZE,24
hl.env("XCURSOR_SIZE", "24")

-- exec-once = wl-paste --watch cliphist store
hl.on("hyprland.start", function() hl.exec_cmd("wl-paste --watch cliphist store") end)

-- general { gaps_in = 4 }  /  decoration { blur { enabled = true } }
hl.config({ general = { gaps_in = 4 }, decoration = { blur = { enabled = true } } })

-- bind = $mod, Q, killactive
hl.bind(mod .. " + Q", hl.dsp.window.close())
-- bind = $mod, 1, workspace, 1   /   bind = $mod SHIFT, 1, movetoworkspace, 1
hl.bind(mod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = "1", follow = true }))
-- bindel = , XF86AudioRaiseVolume, exec, …
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
-- bindm = $mod, mouse:272, movewindow
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })

-- windowrulev2 = workspace 2 silent, class:^(com.mitchellh.ghostty)$
hl.window_rule({ match = { class = "^(com.mitchellh.ghostty)$" }, workspace = "2 silent" })
-- windowrulev2 = float, title:^(Picture-in-Picture)$
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, float = true })
```

## Verify after a change

- **All `hl.*` / `hl.dsp.*` method names above are confirmed against the wiki**, so a config
  using them *loads* (a typo'd method = `attempt to call a nil value` = dead session).
- Argument semantics worth a live sanity-check after editing: fullscreen `action`/`mode`,
  `focus({ workspace = "previous" })`, `window.move` `follow`, and `window_rule` effect keys.
- Editor autocomplete: Hyprland ships Lua stubs at `/usr/share/hypr/stubs`. For VS Code:
  ```json
  { "Lua.workspace.library": ["/usr/share/hypr/stubs"] }
  ```

## Sources

- Hyprland wiki (0.55+): <https://wiki.hypr.land/Configuring/> — `Start`, `Variables`,
  `Binds`, `Dispatchers`, `Monitors`, `Window-Rules`.
- Repo: `github.com/hyprwm/hyprland-wiki` (`content/Configuring/Basics/*.md`).
