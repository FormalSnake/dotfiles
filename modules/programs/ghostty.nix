{...}: {
  # Source aerospace config from the home-manager store
  home.file.".config/ghostty/config".text = ''
    font-family = GeistMono Nerd Font
    font-size = 14
    font-feature = -liga

    # theme = colors
    theme = dark:catppuccin-mocha,light:catppuccin-latte
    # theme = dark:GitHub-Dark-High-Contrast,light:GitHub-Light-High-Contrast
    cursor-style = block
    # cursor-color = #bbbbbb
    adjust-cursor-thickness = 1
    shell-integration = zsh
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
