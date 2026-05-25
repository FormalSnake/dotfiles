# TPM Migration Setup

## Install TPM

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

## Install Plugins

1. Start tmux
2. Press `prefix + I` (capital i) to install plugins
   - Default prefix is `Ctrl-b`

## Plugin Commands

- `prefix + I` - Install plugins
- `prefix + U` - Update plugins
- `prefix + alt + u` - Remove/uninstall plugins not on the list

## Verify Installation

```bash
ls ~/.tmux/plugins/
```

You should see:
- tpm
- tmux-resurrect
- tmux-continuum
- vim-tmux-navigator
- tmux-fzf