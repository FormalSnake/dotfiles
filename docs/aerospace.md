# AeroSpace Window Manager User Guide

AeroSpace is a tiling window manager for macOS that provides vim-like navigation and automatic workspace management. This guide covers the custom configuration included in this Nix setup.

## Overview

The configuration is optimized for:
- **Vim-like navigation** (hjkl keys)
- **Spanish keyboard compatibility** (no Alt+number conflicts)
- **Automatic app workspace assignment**
- **Tiling-focused workflow** with minimal floating windows

## Key Bindings

### Window Navigation (Vim-style)
- `Alt + H` - Focus window to the left
- `Alt + J` - Focus window below
- `Alt + K` - Focus window above  
- `Alt + L` - Focus window to the right

### Window Movement
- `Alt + Shift + H` - Move window left
- `Alt + Shift + J` - Move window down
- `Alt + Shift + K` - Move window up
- `Alt + Shift + L` - Move window right

### Window Management
- `Alt + Q` - Close focused window
- `Alt + Shift + F` - Toggle fullscreen
- `Alt + T` - Force tiles layout (fix any layout issues)

### Window Resizing
- `Alt + Shift + -` - Decrease window size (smart resize)
- `Alt + Shift + =` - Increase window size (smart resize)

### Workspace Management
- `Cmd + 1-9` - Switch to workspace 1-9
- `Cmd + Shift + 1-9` - Move focused window to workspace 1-9
- `Alt + Tab` - Switch between current and previous workspace
- `Alt + Shift + Tab` - Move workspace to next monitor

### Service Mode
- `Alt + Shift + S` - Enter service mode (advanced operations)

## Service Mode Commands

Service mode provides advanced window management. After pressing `Alt + Shift + S`:

- `Esc` - Reload config and exit to main mode
- `R` - Reset layout (flatten workspace tree) and exit
- `F` - Toggle between floating and tiling layout and exit
- `Backspace` - Close all windows except current and exit

### Join Operations (in Service Mode)
- `Alt + Shift + H` - Join with window on the left
- `Alt + Shift + J` - Join with window below
- `Alt + Shift + K` - Join with window above
- `Alt + Shift + L` - Join with window on the right

## Automatic App Workspace Assignment

Apps are automatically moved to designated workspaces when opened:

| Workspace | Apps |
|-----------|------|
| 1 | **Brave Browser** - Web browsing |
| 2 | **Ghostty** - Terminal emulator |
| 3 | **Zed Editor** - Code editor |
| 4 | **Slack & WhatsApp** - Communication |
| 5 | **Notion** - Note-taking and documentation |
| 6 | **Figma** - Design and prototyping |
| 7 | **Claude** - AI assistant |
| 8 | **Spotify** - Music streaming (moves to 2nd monitor if available) |
| 9 | **Steam** - Gaming |

## Configuration Features

### Auto-Start
- AeroSpace starts automatically at login

### Normalization
- Automatically flattens weird container configurations
- Handles nested containers intelligently

### Gaps
- 6px gaps between windows and screen edges
- Consistent spacing for clean appearance

### Mouse Behavior
- Mouse automatically follows window focus
- Mouse centers on focused monitor when switching

### macOS Integration
- Automatically unhides hidden macOS apps
- Uses qwerty key mapping preset

## Tips and Best Practices

### Daily Workflow
1. **Start your day**: Apps will automatically organize into their designated workspaces
2. **Navigate with vim keys**: Use `Alt + hjkl` for quick window focus changes
3. **Move windows naturally**: `Alt + Shift + hjkl` to reorganize your layout
4. **Use workspaces**: `Cmd + numbers` to switch contexts quickly

### Troubleshooting
- **Layout issues**: Press `Alt + T` to force tiles layout
- **Complex reorganization**: Use `Alt + Shift + S` then `R` to reset layout
- **Config not working**: Use `Alt + Shift + S` then `Esc` to reload

### Spanish Keyboard Users
- **Special characters**: `Alt + numbers` work normally (no workspace conflicts)
- **Service mode**: `Alt + Shift + S` avoids conflicts with app shortcuts
- **All navigation**: Uses `hjkl` instead of arrow keys or problematic combinations

## Advanced Usage

### Window Joining
Use service mode join operations to create complex layouts:
1. Enter service mode: `Alt + Shift + S`
2. Use `Alt + Shift + hjkl` to join windows in specific directions
3. Creates tabbed or split container layouts

### Multi-Monitor Setup
- `Alt + Shift + Tab` moves entire workspaces between monitors
- Mouse automatically centers on active monitor
- Each monitor maintains independent workspace sets

### Customization
The configuration is defined in `modules/programs/aerospace.nix` and can be modified to:
- Change key bindings
- Adjust gaps and padding
- Modify app workspace assignments
- Add new window detection rules

## Getting Help

- **Reload config**: Service mode → `Esc`
- **Reset everything**: Service mode → `R` 
- **AeroSpace docs**: [Official Documentation](https://nikitabobko.github.io/AeroSpace/)
- **Key reference**: This guide or check the config file directly

The configuration prioritizes productivity and ergonomics while maintaining compatibility with Spanish keyboard layouts and macOS conventions.