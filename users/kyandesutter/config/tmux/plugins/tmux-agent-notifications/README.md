# tmux-agent-notifications

Per-project notifications for Claude Code agents in your tmux status bar. Each agent gets its own notification that only disappears when you focus that specific pane.

## Features

- Multi-agent support: each project+pane gets its own notification slot
- Smart clearing: notifications disappear only when you focus the exact pane
- Pane-safe: multiple Claude instances in the same project each get their own notification
- Worktree-aware: shows `Project/worktree` instead of just the worktree name
- Dynamic status line: shows as many notifications as fit, with `+N more` overflow
- `prefix + n` jumps to the oldest pending notification
- `prefix + S` opens a notification picker (fzf)
- Notification log viewer
- Fully configurable colors, keybindings, and display options

## Requirements

- tmux 3.2+
- [Claude Code](https://claude.ai/claude-code) CLI
- [fzf](https://github.com/junegunn/fzf) (for notification picker)

## Installation

### With TPM

Add to your `~/.tmux.conf`:

```tmux
set -g @plugin 'kaiiserni/tmux-agent-notifications'
```

Reload tmux: `prefix + I`

### Manual

```bash
git clone https://github.com/kaiiserni/tmux-agent-notifications.git ~/.tmux/plugins/tmux-agent-notifications
```

Add to your `~/.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/tmux-agent-notifications/claude-notifications.tmux
```

## Claude Code Setup

Add the following hooks to your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.tmux/plugins/tmux-agent-notifications/scripts/claude-hook.sh Stop"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.tmux/plugins/tmux-agent-notifications/scripts/claude-hook.sh Notification"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.tmux/plugins/tmux-agent-notifications/scripts/claude-hook.sh UserPromptSubmit"
          }
        ]
      }
    ]
  }
}
```

## Configuration

All options are set via tmux `@` variables. Add these **before** the plugin line in your `~/.tmux.conf`:

### Keybindings

| Option | Default | Description |
|--------|---------|-------------|
| `@claude-notif-key-next` | `n` | Jump to oldest notification |
| `@claude-notif-key-picker` | `S` | Notification picker (fzf) |
| `@claude-notif-key-log` | _(none)_ | Log viewer popup |
| `@claude-notif-key-toggle` | _(none)_ | Toggle status line 2 |

```tmux
set -g @claude-notif-key-next 'n'
set -g @claude-notif-key-picker 'S'
set -g @claude-notif-key-log 'N'
set -g @claude-notif-key-toggle 'T'
```

### Display

| Option | Default | Description |
|--------|---------|-------------|
| `@claude-notif-status-line` | `on` | Enable status line 2 for notifications |
| `@claude-notif-status-bg` | `default` | Background color for status line 2 |
| `@claude-notif-fg` | `#c8d3f5` | Notification text color |
| `@claude-notif-alert-fg` | `yellow` | Alert message color |
| `@claude-notif-alert-style` | `bold` | Alert message style |
| `@claude-notif-separator-fg` | `#444a73` | Separator color between notifications |

```tmux
# TokyoNight Moon theme example
set -g @claude-notif-status-bg '#2f334d'
set -g @claude-notif-fg '#c8d3f5'
set -g @claude-notif-separator-fg '#444a73'
```

## How It Works

```
Claude Code hooks          tmux hooks
     |                          |
     v                          v
claude-hook.sh          clear-notification.sh
     |                          |
     v                          v
~/.claude/.notifications/   (matches pane ID)
  ProjectA__42                  |
  ProjectB__53                  v
  .pane_ProjectA__42      removes matching file
  .pane_ProjectB__53
     |
     v
notification-reader.sh --> status line 2
```

1. When Claude stops or sends a notification, `claude-hook.sh` writes a file per project+pane
2. `notification-reader.sh` reads these files, shows as many as fit the terminal width
3. When you focus a pane, `clear-notification.sh` matches the pane ID and clears the notification
4. Only the matching notification is cleared — others remain visible

## Scripts

| Script | Purpose |
|--------|---------|
| `claude-hook.sh` | Main hook for Claude Code events |
| `notification-reader.sh` | Reads notifications for status line 2 |
| `clear-notification.sh` | Clears notification on pane focus |
| `next-notification.sh` | Jumps to the pane of the oldest notification |
| `notification-picker.sh` | fzf picker to select and jump to a notification |
| `log-viewer.sh` | Notification log viewer popup |

## License

MIT
