if [[ -f "/opt/homebrew/bin/brew" ]]; then
  # If you're using macOS, you'll want this enabled
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

#Gitstatus
source /opt/homebrew/opt/gitstatus/gitstatus.plugin.zsh
source ~/.config/zsh/gitstatus/mod_gitstatus.prompt.zsh

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Add snippets
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::command-not-found
zinit snippet OMZP::brew

# Load completions
autoload -Uz compinit && compinit

zinit cdreplay -q

# Customize prompt
# if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
#   eval "$(oh-my-posh init zsh --config $HOME/.config/ohmyposh/base.toml)"
# fi
# source /opt/homebrew/opt/gitstatus/gitstatus.prompt.zsh
unsetopt PROMPT_SP

my_git_status() {
   echo $GITSTATUS_PROMPT
}
GEOMETRY_STATUS_SYMBOL="󰅟 "             # default prompt symbol
GEOMETRY_STATUS_SYMBOL_ERROR="󰅣 "       # displayed when exit value is != 0
GEOMETRY_PATH_SHOW_BASENAME=true
GEOMETRY_PATH_COLOR="magenta"
GEOMETRY_RPROMPT=(geometry_exec_time my_git_status geometry_echo)
source /opt/homebrew/opt/geometry/share/geometry/geometry.zsh

# History settings
HISTSIZE=5000
HISTFILE="${HOME}/.zsh_history"
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory sharehistory hist_ignore_space hist_ignore_all_dups hist_save_no_dups hist_ignore_dups hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Aliases
alias ls='ls -A --color'
alias vim='nvim'
alias c='clear'

# Git aliases
alias add='git add'
alias commit='git commit'
alias push='git push'
# alias neofetch='clear && pokeget Psyduck --hide-name | fastfetch --file-raw -'
alias neofetch='clear && ftch'
alias commitai='commit_message=$(lumen draft) && git commit -avm "$commit_message"'
alias nah='git reset --hard && git clean -df'

gpush() {
  git add .

  commit_message=$(lumen draft)
  
  if [ -z "$commit_message" ]; then
    echo "Lumen draft is empty"
    echo -n "Enter commit message: "
    read commit_message
  fi
  
  git commit -avm "$commit_message"
  git push origin main
}

# Shell integrations
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"


# Set default editor
export EDITOR="nvim"

# Bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# yazi
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# Pywal
wal() {
    # Define the path to your virtual environment directory
    VENV_DIR="./pywal_env"  # Change this to your specific venv directory if needed

    # Check if the virtual environment directory exists
    if [ -d "$VENV_DIR" ]; then
        # Activate the virtual environment
        source "$VENV_DIR/bin/activate"
    fi

    # Run the wal command with any arguments passed to this function
    command wal "$@"
}

# Aider config
export AIDER_CACHE_PROMPTS="true"
export AIDER_CACHE_KEEPALIVE_PINGS="6"
export AIDER_MAP_MULTIPLIER_NO_FILES="2"
export AIDER_INPUT_HISTORY_FILE=".aiih"
export AIDER_CHAT_HISTORY_FILE=".aich.md"
export AIDER_DARK_MODE="true"
export AIDER_CODE_THEME="monokai"
export AIDER_SHOW_DIFFS="false"
export AIDER_GITIGNORE="false"
export AIDER_AIDERIGNORE=".aig"
export AIDER_WATCH_FILES="true"
export AIDER_READ="CONVENTIONS.md"
export AIDER_VIM="true"
export AIDER_CHAT_LANGUAGE="English"
export AIDER_SUGGEST_SHELL_COMMANDS="true"
export AIDER_FANCY_INPUT="true"
export AIDER_VOICE_FORMAT="mp3"
export AIDER_VOICE_LANGUAGE="en"

# bun completions
[ -s "/Users/kyandesutter/.bun/_bun" ] && source "/Users/kyandesutter/.bun/_bun"

# Created by `pipx` on 2024-12-27 11:26:44
export PATH="$PATH:/Users/kyandesutter/.local/bin"
