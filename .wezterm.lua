local wezterm = require("wezterm")
local padding = 24

return {
  font_size = 14,
  font = wezterm.font("GeistMono Nerd Font"),
  scrollback_lines = 10000,
  enable_tab_bar = false,
  audible_bell = "Disabled",
  line_height = 1.4,
  adjust_window_size_when_changing_font_size = false,
  window_decorations = "RESIZE",
  window_close_confirmation = "NeverPrompt",
  -- window_background_opacity = 0.85,
  -- macos_window_background_blur = 20,
  term = "xterm-256color",
  color_scheme = "Ayu Dark (Gogh)",
  -- color_scheme = "ayu_light",
  max_fps = 160,
  window_padding = {
    left = padding,
    right = padding,
    top = padding,
    bottom = padding / 2,
  },
  send_composed_key_when_left_alt_is_pressed = true,
  send_composed_key_when_right_alt_is_pressed = false,
}
