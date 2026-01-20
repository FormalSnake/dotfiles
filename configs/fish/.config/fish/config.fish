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

    # Cargo
    fish_add_path ~/.cargo/bin

    # Bun
    fish_add_path ~/.bun/bin

    # macOS-specific paths
    if test (uname) = Darwin
        # Python paths
        fish_add_path ~/Library/Python/3.9/bin

        # Java Home
        set -gx JAVA_HOME /Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home

        # Android SDK
        set -gx ANDROID_HOME $HOME/Library/Android/sdk
        fish_add_path $ANDROID_HOME/emulator
        fish_add_path $ANDROID_HOME/platform-tools

        # Added by Antigravity
        fish_add_path $HOME/.antigravity/antigravity/bin
    end

    # Linux-specific (CachyOS/Arch)
    if test (uname) = Linux
        if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
            source /usr/share/cachyos-fish-config/cachyos-config.fish
        end
    end

    # Load secrets
    if test -f ~/.config/fish/secrets.fish
        source ~/.config/fish/secrets.fish
    end
end

export PATH="$HOME/.local/bin:$PATH"
