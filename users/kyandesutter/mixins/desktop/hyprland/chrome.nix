{ lib, flexoki, fsRadius, ... }:
''
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
    primary = "rgb(${lib.removePrefix "#" flexoki.accents.blue.d})",
    border = "rgb(${lib.removePrefix "#" flexoki.base.b700})",
    destructive = "rgb(${lib.removePrefix "#" flexoki.accents.red.d})",
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
    rounding = ${fsRadius},
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
''
