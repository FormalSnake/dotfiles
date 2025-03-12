{
  config,
  pkgs,
  ...
}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    history = {
      size = 5000;
      save = 5000;
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      share = true;
    };

    initExtra = ''
            # Set up brew environment if on macOS
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
              eval "$(/opt/homebrew/bin/brew shellenv)"
            fi

            # Shell integrations
            eval "$(fzf --zsh)"
            eval "$(zoxide init --cmd cd zsh)"

      #Gitstatus
      source /opt/homebrew/opt/gitstatus/gitstatus.plugin.zsh
      source ~/.config/zsh/gitstatus/mod_gitstatus.prompt.zsh

      unsetopt PROMPT_SP

      my_git_status() {
         echo $GITSTATUS_PROMPT
      }
      GEOMETRY_STATUS_SYMBOL="󰅟 "             # default prompt symbol
      GEOMETRY_STATUS_SYMBOL_ERROR="󰅣 "       # displayed when exit value is != 0
      GEOMETRY_PATH_SHOW_BASENAME=true
      GEOMETRY_RPROMPT=(geometry_exec_time my_git_status geometry_echo)
      source /opt/homebrew/opt/geometry/share/geometry/geometry.zsh

            # Define LS_COLORS properly
            zstyle ":completion:*" list-colors "$LS_COLORS"

            # Aliases
            alias ls='ls -A --color'
            alias vim='nvim'
            alias add='git add'
            alias commit='git commit'
            alias push='git push'
            alias neofetch='clear && ftch && echo'
            alias commitai='commit_message=$(lumen draft) && git commit -avm "$commit_message"'
            alias nah='git reset --hard && git clean -df'
            alias nixrb='clear && darwin-rebuild switch --flake .'
            alias nixrbgc='clear && darwin-rebuild switch --flake . && nix-store --gc'
            alias docker=podman

            # Functions
            function gpush() {
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
    '';

    plugins = with pkgs; [
      {
        name = "fzf-tab";
        src = fetchFromGitHub {
          owner = "Aloxaf";
          repo = "fzf-tab";
          rev = "master";
          sha256 = "sha256-q26XVS/LcyZPRqDNwKKA9exgBByE0muyuNb0Bbar2lY=";
        };
      }
      {
        name = "zsh-syntax-highlighting";
        src = zsh-syntax-highlighting;
      }
      {
        name = "zsh-completions";
        src = zsh-completions;
      }
      {
        name = "zsh-autosuggestions";
        src = zsh-autosuggestions;
      }
    ];
  };

  # programs.zsh = {
  #   enable = true;
  #   enableCompletion = true;
  #   autosuggestion.enable = true;
  #   syntaxHighlighting.enable = true;
  #   history.size = 5000;
  #   history.path = "${config.xdg.dataHome}/zsh/history";
  #   shellAliases = {
  #     ls = "ls -A --color";
  #     vim = "nvim";
  #     add = "git add";
  #     commit = "git commit";
  #     push = "git push";
  #     neofetch = "clear && ftch && echo";
  #     commitai = "commit_message=$(lumen draft) && git commit -avm \"$commit_message\"";
  #     nah = "git reset --hard && git clean -df";
  #     nixrb = "clear && darwin-rebuild switch --flake .";
  #     nixrbgc = "clear && darwin-rebuild switch --flake . && nix-store --gc";
  #   };
  #   initExtra = ''
  #     # Load Homebrew if available
  #     if [[ -f "$(command -v brew)" ]]; then
  #       eval "$(brew shellenv)"
  #     fi
  #
  #     # Zinit setup
  #     ZINIT_HOME="$XDG_DATA_HOME/zinit/zinit.git"
  #     [[ ! -d "$ZINIT_HOME" ]] && mkdir -p "$ZINIT_HOME" && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
  #     source "$ZINIT_HOME/zinit.zsh"
  #
  #     # Load plugins
  #     zinit light zsh-users/zsh-syntax-highlighting
  #     zinit light zsh-users/zsh-completions
  #     zinit light zsh-users/zsh-autosuggestions
  #     zinit light Aloxaf/fzf-tab
  #     zinit snippet OMZP::git
  #     zinit snippet OMZP::sudo
  #     zinit snippet OMZP::command-not-found
  #     zinit snippet OMZP::brew
  #     zinit cdreplay -q
  #
  #     # Gitstatus
  #     [[ -f "${pkgs.gitstatus}/gitstatus.plugin.zsh" ]] && source "${pkgs.gitstatus}/gitstatus.plugin.zsh"
  #
  #     # Prompt setup
  #     source /opt/homebrew/opt/geometry/share/geometry/geometry.zsh
  #     GEOMETRY_STATUS_SYMBOL="󰅟 "
  #     GEOMETRY_STATUS_SYMBOL_ERROR="󰅣 "
  #     GEOMETRY_PATH_SHOW_BASENAME=true
  #     GEOMETRY_RPROMPT=(geometry_exec_time my_git_status geometry_echo)
  #
  #     # Completion setup
  #     autoload -Uz compinit && compinit -C
  #     zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
  #     zstyle ":completion:*" list-colors "$LS_COLORS"
  #     zstyle ':completion:*' menu no
  #
  #     # Shell integrations
  #     eval "$(fzf --zsh)"
  #     eval "$(zoxide init --cmd cd zsh)"
  #
  #     # Set default editor
  #     export EDITOR="nvim"
  #   '';
  # };
}
