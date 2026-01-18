# Formalconf Theme System

## Theme System Overview

The `current/` folder contains symbolic links pointing to the active theme files. This is a symlink-based theme activation system.

### Structure

```
current/
├── theme/           # Symlinks to active theme files
│   ├── alacritty.toml
│   ├── btop.theme
│   ├── ghostty.conf
│   ├── hyprland.conf
│   ├── hyprlock.conf
│   ├── kitty.conf
│   ├── mako.ini
│   ├── neovim.lua
│   ├── vscode.json
│   ├── waybar.css
│   ├── walker.css
│   └── ...
└── backgrounds/     # Symlink to active theme's wallpapers
```

### How It Works

1. **Symlink Activation**: All files in `current/theme/` are symlinks pointing to the corresponding files in `themes/<active-theme>/`
2. **Application Integration**: Applications source their theme from `current/theme/` (e.g., Hyprland sources `~/.config/formalconf/current/theme/hyprland.conf`)
3. **Theme Switching**: Changing themes relinks all files in `current/` to a different theme directory

### Available Themes

Themes are stored in `themes/` directory: catppuccin, gruvbox, tokyo-night, rose-pine, nord, kanagawa, everforest, and others.

### Supported Applications

Terminals (Alacritty, Kitty, Ghostty), Hyprland, Waybar, Mako, Walker, Neovim, VS Code, btop, Swayosd, and more.

---

## AI Restrictions

**The AI cannot access or execute the formalconf CLI.**

Theme switching and package management via the formalconf CLI is user-only. The AI should:
- Read and understand theme files
- Edit individual theme configuration files if requested
- Document or explain the theme system

The AI should NOT attempt to:
- Run formalconf commands
- Switch themes programmatically
- Manage packages through formalconf
