#!/usr/bin/env fish

# Fish configuration file
# Migrated from Nix-generated configuration

# Disable greeting
set -g fish_greeting ""

# Interactive shell initialization
if status is-interactive
    # FZF integration
    if type -q fzf
        fzf --fish | source
    end

    # Zoxide integration
    if type -q zoxide
        zoxide init fish | source
    end

    # Set TERM for Ghostty
    if test "$TERM_PROGRAM" = ghostty
        set -gx TERM xterm-256color
        set -gx SNACKS_GHOSTTY true
    end

    # Load brew environment on macOS
    if test -f /opt/homebrew/bin/brew
        eval (/opt/homebrew/bin/brew shellenv)
    end

    # Paths

    # Python paths
    fish_add_path ~/Library/Python/3.9/bin

    # FormalConf path
    fish_add_path ~/formalconf

    # Load secrets
    if test -f ~/.config/fish/secrets.fish
        source ~/.config/fish/secrets.fish
    end
end

export PATH="$HOME/.local/bin:$PATH"
