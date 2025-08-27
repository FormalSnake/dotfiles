{
  pkgs,
  config,
  lib,
  ...
}: let
  currentTheme = config.themes.available.${config.themes.current or "catppuccin"};
  ghosttyTheme = currentTheme.ghostty.theme or "catppuccin-mocha";
in {
  # Create a script to generate ghostty config dynamically
  home.packages = [
    (pkgs.writeShellScriptBin "update-ghostty-config" ''
      THEME_FILE=~/.config/nix-themes/current-ghostty
      CONFIG_FILE=~/.config/ghostty/config
      
      if [[ -L "$THEME_FILE" ]]; then
        THEME=$(cat "$THEME_FILE")
      else
        THEME="catppuccin-mocha"
      fi
      
      cat > "$CONFIG_FILE" << EOF
# command = ${pkgs.fish}/bin/fish --login -c "if command -v ${pkgs.tmux}/bin/tmux >/dev/null 2>&1; ${pkgs.tmux}/bin/tmux attach || ${pkgs.tmux}/bin/tmux; else; ${pkgs.fish}/bin/fish; end"
font-family = GeistMono Nerd Font
font-size = 12
font-feature = -liga

theme = $THEME
cursor-style = block
# cursor-color = #bbbbbb
adjust-cursor-thickness = 1
shell-integration = fish
shell-integration-features = true
background-opacity = 0.85
background-blur-radius = 32

keybind = cmd+shift+space=toggle_quick_terminal

mouse-hide-while-typing = true
macos-titlebar-style = tabs
# Square corners
# window-decoration = false
# macos-window-shadow = false

window-padding-x = 11
window-padding-y = 11
window-padding-balance = true
window-colorspace = display-p3

# macos-icon = custom-style
# macos-icon-ghost-color = c7c6c6
# macos-icon-screen-color = 201e1e
# macos-icon-frame = plastic

clipboard-read = allow
clipboard-write = allow
EOF
    '')
  ];
  
  # Create initial config file with fallback theme
  home.file.".config/ghostty/config".text = ''
# command = ${pkgs.fish}/bin/fish --login -c "if command -v ${pkgs.tmux}/bin/tmux >/dev/null 2>&1; ${pkgs.tmux}/bin/tmux attach || ${pkgs.tmux}/bin/tmux; else; ${pkgs.fish}/bin/fish; end"
font-family = GeistMono Nerd Font
font-size = 12
font-feature = -liga

theme = ${ghosttyTheme}
cursor-style = block
# cursor-color = #bbbbbb
adjust-cursor-thickness = 1
shell-integration = fish
shell-integration-features = true
background-opacity = 0.85
background-blur-radius = 32

keybind = cmd+shift+space=toggle_quick_terminal

mouse-hide-while-typing = true
macos-titlebar-style = tabs
# Square corners
# window-decoration = false
# macos-window-shadow = false

window-padding-x = 11
window-padding-y = 11
window-padding-balance = true
window-colorspace = display-p3

# macos-icon = custom-style
# macos-icon-ghost-color = c7c6c6
# macos-icon-screen-color = 201e1e
# macos-icon-frame = plastic

clipboard-read = allow
clipboard-write = allow
  '';
}
