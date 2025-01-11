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
alias neofetch='clear && pokeget Psyduck --hide-name | fastfetch --file-raw -'
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

# TMUXIFIER
export PATH="$HOME/.tmuxifier/bin:$PATH"
eval "$(tmuxifier init -)"

# Set default editor
export EDITOR="nvim"

# Deno
export DENO_INSTALL="$HOME/.deno"
export PATH="$HOME/.deno/bin:$PATH"
[ -s "$DENO_INSTALL/env" ] && . "$DENO_INSTALL/env"

# Bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# Windsurf
export PATH="$HOME/.codeium/windsurf/bin:$PATH"
alias shuf='gshuf'

export PATH="$HOME/Developer/depot_tools:$PATH"

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

# Pywal which is installed in a virtual environment using pip
# export wal="$HOME/.pywal_venv/bin/wal"

# export OPENAI_API_KEY=
# export ANTHROPIC_API_KEY=
# export AIDER_OPENAI_API_KEY=
# export AIDER_ANTHROPIC_API_KEY=
# export AIDER_MODEL=
# export AIDER_OPUS=
# export AIDER_SONNET=
# export AIDER_HAIKU=
# export AIDER_4=
# export AIDER_4O=
# export AIDER_MINI=
# export AIDER_4_TURBO=
# export AIDER_35TURBO=
# export AIDER_DEEPSEEK=
# export AIDER_O1_MINI=
# export AIDER_O1_PREVIEW=
# export AIDER_LIST_MODELS=
# export AIDER_OPENAI_API_BASE=
# export AIDER_OPENAI_API_TYPE=
# export AIDER_OPENAI_API_VERSION=
# export AIDER_OPENAI_API_DEPLOYMENT_ID=
# export AIDER_OPENAI_ORGANIZATION_ID=
# export AIDER_MODEL_SETTINGS_FILE=".aider.model.settings.yml"
# export AIDER_MODEL_METADATA_FILE=".aider.model.metadata.json"
# export AIDER_ALIAS=
# export AIDER_VERIFY_SSL="true"
# export AIDER_TIMEOUT=
# export AIDER_EDIT_FORMAT=
# export AIDER_ARCHITECT=
# export AIDER_WEAK_MODEL=
# export AIDER_EDITOR_MODEL=
# export AIDER_EDITOR_EDIT_FORMAT=
# export AIDER_SHOW_MODEL_WARNINGS="true"
# export AIDER_MAX_CHAT_HISTORY_TOKENS=
# export AIDER_ENV_FILE=".env"
export AIDER_CACHE_PROMPTS="true"
export AIDER_CACHE_KEEPALIVE_PINGS="6"
# export AIDER_MAP_TOKENS=
# export AIDER_MAP_REFRESH="auto"
export AIDER_MAP_MULTIPLIER_NO_FILES="2"
export AIDER_INPUT_HISTORY_FILE=".aiih"
export AIDER_CHAT_HISTORY_FILE=".aich.md"
# export AIDER_RESTORE_CHAT_HISTORY="false"
# export AIDER_LLM_HISTORY_FILE=
export AIDER_DARK_MODE="true"
# export AIDER_LIGHT_MODE="false"
# export AIDER_PRETTY="true"
# export AIDER_STREAM="true"
# export AIDER_USER_INPUT_COLOR="#00cc00"
# export AIDER_TOOL_OUTPUT_COLOR=
# export AIDER_TOOL_ERROR_COLOR="#FF2222"
# export AIDER_TOOL_WARNING_COLOR="#FFA500"
# export AIDER_ASSISTANT_OUTPUT_COLOR="#0088ff"
# export AIDER_COMPLETION_MENU_COLOR=
# export AIDER_COMPLETION_MENU_BG_COLOR=
# export AIDER_COMPLETION_MENU_CURRENT_COLOR=
# export AIDER_COMPLETION_MENU_CURRENT_BG_COLOR=
export AIDER_CODE_THEME="monokai"
export AIDER_SHOW_DIFFS="false"
# export AIDER_GIT="true"
export AIDER_GITIGNORE="false"
export AIDER_AIDERIGNORE=".aig"
# export AIDER_SUBTREE_ONLY="false"
# export AIDER_AUTO_COMMITS="true"
# export AIDER_DIRTY_COMMITS="true"
# export AIDER_ATTRIBUTE_AUTHOR="true"
# export AIDER_ATTRIBUTE_COMMITTER="true"
# export AIDER_ATTRIBUTE_COMMIT_MESSAGE_AUTHOR="false"
# export AIDER_ATTRIBUTE_COMMIT_MESSAGE_COMMITTER="false"
# export AIDER_COMMIT="false"
# export AIDER_COMMIT_PROMPT=
# export AIDER_DRY_RUN="false"
# export AIDER_SKIP_SANITY_CHECK_REPO="false"
export AIDER_WATCH_FILES="true"
# export AIDER_COPY_PASTE="false"
# export AIDER_LINT="false"
# export AIDER_LINT_CMD=
# export AIDER_AUTO_LINT="true"
# export AIDER_TEST_CMD=
# export AIDER_AUTO_TEST="false"
# export AIDER_TEST="false"
# export AIDER_ANALYTICS=
# export AIDER_ANALYTICS_LOG=
# export AIDER_ANALYTICS_DISABLE="false"
# export AIDER_FILE=
export AIDER_READ="CONVENTIONS.md"
export AIDER_VIM="true"
export AIDER_CHAT_LANGUAGE="English"
# export AIDER_JUST_CHECK_UPDATE="false"
# export AIDER_CHECK_UPDATE="true"
# export AIDER_SHOW_RELEASE_NOTES=
# export AIDER_INSTALL_MAIN_BRANCH="false"
# export AIDER_UPGRADE="false"
# export AIDER_APPLY=
# export AIDER_APPLY_CLIPBOARD_EDITS="false"
# export AIDER_YES_ALWAYS=
# export AIDER_VERBOSE="false"
# export AIDER_SHOW_REPO_MAP="false"
# export AIDER_SHOW_PROMPTS="false"
# export AIDER_EXIT="false"
# export AIDER_MESSAGE=
# export AIDER_MESSAGE_FILE=
# export AIDER_LOAD=
# export AIDER_ENCODING="utf-8"
# export AIDER_GUI="false"
export AIDER_SUGGEST_SHELL_COMMANDS="true"
export AIDER_FANCY_INPUT="true"
# export AIDER_DETECT_URLS="true"
# export AIDER_EDITOR=
# export AIDER_SET_ENV=
# export AIDER_API_KEY=
export AIDER_VOICE_FORMAT="mp3"
export AIDER_VOICE_LANGUAGE="en"
# export AIDER_VOICE_INPUT_DEVICE=

# bun completions
[ -s "/Users/kyandesutter/.bun/_bun" ] && source "/Users/kyandesutter/.bun/_bun"

# Created by `pipx` on 2024-12-27 11:26:44
export PATH="$PATH:/Users/kyandesutter/.local/bin"
