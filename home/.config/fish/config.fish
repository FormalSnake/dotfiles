# Only execute this file once per shell.
set -q __fish_kyan_config_sourced; and exit
set -g __fish_kyan_config_sourced 1

# Session variables. environment.d/10-session.conf sets the same ones for the
# systemd user session; fish needs them for ssh and mosh logins.
set -gx BROWSER helium
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx PAGER less
set -gx LESS -FRX
set -gx LANG en_US.UTF-8
set -gx GSK_RENDERER gl
set -gx GTK2_RC_FILES ~/.gtkrc-2.0
set -gx HYPRCURSOR_SIZE 24
set -gx HYPRCURSOR_THEME Bibata-Modern-Classic
set -gx XCURSOR_SIZE 24
set -gx XCURSOR_THEME Bibata-Modern-Classic
set -gx PORTLESS_TAILSCALE 1
set -gx FZF_DEFAULT_OPTS '--color bg:#100F0F,bg+:#1C1B1A,border:#AF3029,fg:#878580,fg+:#878580,gutter:#100F0F,header:#CECDC3,hl:#CECDC3,hl+:#CECDC3,info:#24837B,marker:#AF3029,pointer:#AD8301,prompt:#AD8301,separator:#1C1B1A,spinner:#24837B'

# Lumen reuses the OpenAI key under a different name
if set -q OPENAI_API_KEY
    set -gx LUMEN_AI_PROVIDER openai
    set -gx LUMEN_API_KEY $OPENAI_API_KEY
    set -gx LUMEN_AI_MODEL gpt-5-mini
end

# Non-secret AI provider settings (formerly in .zprofile).
set -gx OLLAMA_API_BASE "https://ollama.kaiiserni.com"
set -gx AIDER_WEAK_MODEL "gemini/gemini-2.0-flash"

# OpenSSH 10.1+ creates forwarded-agent sockets under ~/.ssh/agent/ and
# unlinks them when their ssh session ends. Mosh's bootstrap ssh does
# exactly that right after spawning mosh-server, so every shell inside a
# mosh session (and anything launched from it, herdr, Claude) inherits a
# dead SSH_AUTH_SOCK. When the socket is gone, fall back to the local gcr
# agent (it holds this machine's on-disk key, which every host's sudo
# mesh and authorized_keys accept). A live forwarded socket is kept as-is
# (it carries the connecting host's richer keyring).
if not test -S "$SSH_AUTH_SOCK"; and test -S "$XDG_RUNTIME_DIR/gcr/ssh"
    set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/gcr/ssh"
end

status is-interactive; and begin

    # Aliases
    alias add 'git add'
    alias cat bat
    alias cd z
    alias codex 'codex --dangerously-bypass-approvals-and-sandbox'
    alias commit 'git commit'
    alias commitai 'set commit_message (lumen draft); and git commit -avm "$commit_message"'
    alias find fd
    alias grep rg
    alias la 'lsd -A'
    alias ld lazydocker
    alias lg lazygit
    alias ll 'lsd -l'
    alias lla 'lsd -lA'
    alias llt 'lsd -l --tree'
    alias ls lsd
    alias lt 'lsd --tree'
    alias nah 'git reset --hard && git clean -df'
    alias push 'git push'
    alias top btop
    alias vim nvim
    alias y yazi

    fzf --fish | source

    # Disable greeting
    set -g fish_greeting ""

    # Set TERM for Ghostty
    if test "$TERM_PROGRAM" = ghostty
        set -gx TERM xterm-256color
        set -gx SNACKS_GHOSTTY true
    end

    # User paths
    fish_add_path /opt/fspec/current/bin
    fish_add_path ~/.cargo/bin
    fish_add_path ~/.bun/bin
    fish_add_path ~/.local/bin

    zoxide init fish | source

    set -q CLAUDECODE; or fastfetch

    fish_config theme choose "Flexoki Dark"
    if not functions -q __direnv_export_eval
        direnv hook fish | source
    end

end
