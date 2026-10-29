# tmux-agent-notifications

Per-project notifications for AI coding agents in your tmux status bar. Supports Claude Code, Codex CLI, and any custom tool via the shared notification library.

## Features

- **Multi-tool support**: notifications from Claude Code, Codex CLI, or custom tools — each prefixed with its source
- Multi-agent support: each project+pane gets its own notification slot
- Smart clearing: notifications disappear only when you focus the exact pane
- Clear-on-jump: jumping to a notification automatically clears it
- Pane-safe: multiple agent instances in the same project each get their own notification
- Worktree-aware: shows `Project/worktree` instead of just the worktree name
- Dead pane cleanup: stale notifications from closed panes are automatically removed
- Stale notification cleanup: notifications older than 30 minutes are pruned on pane focus
- Dynamic status line: shows as many notifications as fit, with `+N more` overflow
- `prefix + n` jumps to the oldest pending notification
- `prefix + S` opens a notification picker (fzf)
- Notification log viewer with source filtering
- Fully configurable colors, keybindings, and display options

## Notification Format

Notifications are prefixed with their source tool:

```
[14:32:01] Claude/my-project: Agent has finished
[14:33:15] Codex/my-project: Needs your approval
[14:35:42] Claude/my-project (session): Task completed
```

## Requirements

- tmux 3.2+
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

### Option A: Claude Code Plugin (recommended)

Install the companion Claude Code plugin to automatically register hooks:

```bash
claude plugin marketplace add kaiiserni/claude-plugin-tmux-notifications
claude plugin install tmux-agent-notifications@claude-plugin-tmux-notifications
```

### Option B: Manual hooks

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

## Codex CLI Setup

Run the included installer to add the notification hook to your Codex config:

```bash
~/.tmux/plugins/tmux-agent-notifications/codex/install.sh
```

This adds the `notify` path to `~/.codex/config.toml`. If you already have a `notify` key, the installer will tell you what to add manually.

## Custom Tool Integration

You can integrate any tool by sourcing `tmux-notify-lib.sh` in your own hook script. Set `NOTIFY_SOURCE` before sourcing to label your notifications:

```bash
#!/usr/bin/env bash
NOTIFY_SOURCE="MyTool"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/tmux-notify-lib.sh"

DISPLAY_NAME=$(resolve_project_name "/path/to/project")

log_event "done" "Task finished" "$DISPLAY_NAME"
tmux_alert "Task finished" "$DISPLAY_NAME"
```

The library provides:

| Function | Purpose |
|----------|---------|
| `resolve_project_name "$cwd"` | Extracts project name (worktree-aware) |
| `tmux_alert "$msg" "$name" "$session"` | Creates a notification (skips if user is watching) |
| `tmux_clear_alert "$name"` | Clears the notification for this pane |
| `log_event "$icon" "$msg" "$name" "$session"` | Appends to `events.log` |
| `is_user_watching` | Returns 0 if the user is focused on the current pane |
| `refresh_all_clients` | Refreshes all tmux clients |

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
Tool hooks                 tmux hooks
(Claude, Codex, ...)       (pane focus)
     |                          |
     v                          v
tmux-notify-lib.sh      clear-notification.sh
     |                          |
     v                          v
~/.tmux-notifications/     (matches pane ID,
  ProjectA__42              cleans dead panes,
  ProjectB__53              prunes stale notifs)
  .pane_ProjectA__42             |
  .pane_ProjectB__53             v
     |                     removes matching file
     v
notification-reader.sh --> status line 2
```

1. When a tool fires a hook, the tool-specific script sources `tmux-notify-lib.sh` and calls `tmux_alert`
2. `tmux_alert` writes a notification file per project+pane to `~/.tmux-notifications/`
3. `notification-reader.sh` reads these files and renders as many as fit the terminal width
4. When you focus a pane, `clear-notification.sh` matches the pane ID and clears the notification
5. Dead panes and notifications older than 30 minutes are automatically cleaned up

## Scripts

| Script | Purpose |
|--------|---------|
| `tmux-notify-lib.sh` | Shared notification library (sourced by all tool hooks) |
| `claude-hook.sh` | Claude Code hook (sets `NOTIFY_SOURCE=Claude`) |
| `codex/notify.sh` | Codex CLI hook (sets `NOTIFY_SOURCE=Codex`) |
| `codex/install.sh` | Codex CLI installer (adds notify to config.toml) |
| `notification-reader.sh` | Reads notifications for status line 2 |
| `clear-notification.sh` | Clears notification on pane focus + dead pane cleanup |
| `next-notification.sh` | Jumps to the pane of the oldest notification |
| `notification-picker.sh` | fzf picker to select and jump to a notification |
| `log-viewer.sh` | Notification log viewer popup |

## Migrating from Previous Versions

If you're upgrading from an earlier version:

1. **Notification directory moved**: `~/.claude/.notifications` is no longer used. Notifications now live in `~/.tmux-notifications/`. You can safely delete the old directory:
   ```bash
   rm -rf ~/.claude/.notifications
   ```

2. **Hook format changed**: The hook scripts now source `tmux-notify-lib.sh` instead of handling notifications inline. If you had custom hooks, update them to use the library (see [Custom Tool Integration](#custom-tool-integration)).

3. **NOTIFY_SOURCE prefix**: All notifications now include a source label (`Claude/`, `Codex/`, etc.). This is automatic — no configuration needed.

## License

MIT
