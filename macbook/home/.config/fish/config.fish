# Only execute this file once per shell.
set -q __fish_kyan_config_sourced; and exit
set -g __fish_kyan_config_sourced 1

# Session variables. launchd agents do not read these; each one sets its own.
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx PAGER less
set -gx LESS -FRX
set -gx LANG en_US.UTF-8
set -gx PORTLESS_TAILSCALE 1
set -gx ANDROID_HOME ~/Library/Android/sdk
set -gx JAVA_HOME /Library/Java/JavaVirtualMachines/zulu-21.jdk/Contents/Home
fish_add_path --append $ANDROID_HOME/platform-tools $ANDROID_HOME/emulator $ANDROID_HOME/cmdline-tools/latest/bin

# Secrets written by fspec at /var/run/fspec/secrets/<name>.
function __load_fspec_secret -a env_name file
    if test -r "/var/run/fspec/secrets/$file"
        set -gx $env_name (cat "/var/run/fspec/secrets/$file")
    end
end
__load_fspec_secret OPENAI_API_KEY openai
# Deliberately NOT loading ANTHROPIC_API_KEY (Claude Code prefers it over
# the claude.ai OAuth session, so every terminal ran on API billing
# instead of the Max plan).
__load_fspec_secret GEMINI_API_KEY gemini
__load_fspec_secret DEEPSEEK_API_KEY deepseek
__load_fspec_secret NUCLEO_LICENSE_KEY nucleo-license
__load_fspec_secret NPM_GITHUB_TOKEN npm-github-token
__load_fspec_secret NPM_REGISTRY_TOKEN npm-registry-token
__load_fspec_secret WSTUNNEL_PATH_PREFIX wstunnel-path-prefix
__load_fspec_secret WSTUNNEL_ENDPOINT wstunnel-endpoint

# Lumen reuses the OpenAI key under a different name
if set -q OPENAI_API_KEY
    set -gx LUMEN_AI_PROVIDER openai
    set -gx LUMEN_API_KEY $OPENAI_API_KEY
    set -gx LUMEN_AI_MODEL gpt-5-mini
end

# Non-secret AI provider settings (formerly in .zprofile).
set -gx OLLAMA_API_BASE "https://ollama.kaiiserni.com"
set -gx AIDER_WEAK_MODEL "gemini/gemini-2.0-flash"

status is-login; and begin

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

    # Brew environment
    if test -f /opt/homebrew/bin/brew
        /opt/homebrew/bin/brew shellenv | source
    end

    # Tools from the fspec store.
    fish_add_path /opt/fspec/current/bin

    # User paths
    fish_add_path ~/.cargo/bin
    fish_add_path ~/.bun/bin
    fish_add_path ~/.local/bin

    # OrbStack shell integration
    if test -f ~/.orbstack/shell/init2.fish
        source ~/.orbstack/shell/init2.fish
    end

    zoxide init fish | source

    set -q CLAUDECODE; or fastfetch

    if test (defaults read -g AppleInterfaceStyle 2>/dev/null) = Dark
        fish_config theme choose "Flexoki Dark"
    else
        fish_config theme choose "Flexoki Light"
    end

    if not functions -q __direnv_export_eval
        direnv hook fish | source
    end

end
