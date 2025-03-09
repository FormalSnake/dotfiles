{
  config,
  pkgs,
  ...
}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableAutosuggestions = true;
    syntaxHighlighting.enable = true;
    history.size = 5000;
    history.path = "${config.xdg.dataHome}/zsh/history";
    shellAliases = {
      ls = "ls -A --color";
      vim = "nvim";
      add = "git add";
      commit = "git commit";
      push = "git push";
      neofetch = "clear && ftch && echo";
      commitai = "commit_message=$(lumen draft) && git commit -avm \"$commit_message\"";
      nah = "git reset --hard && git clean -df";
      nixrb = "clear && darwin-rebuild switch --flake .";
      nixrbgc = "clear && darwin-rebuild switch --flake . && nix-store --gc";
    };
    initExtra = ''
      # Load Homebrew if available
      if [[ -f "$(command -v brew)" ]]; then
        eval "$(brew shellenv)"
      fi

      # Zinit setup
      ZINIT_HOME="$XDG_DATA_HOME/zinit/zinit.git"
      [[ ! -d "$ZINIT_HOME" ]] && mkdir -p "$ZINIT_HOME" && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
      source "$ZINIT_HOME/zinit.zsh"

      # Load plugins
      zinit light zsh-users/zsh-syntax-highlighting
      zinit light zsh-users/zsh-completions
      zinit light zsh-users/zsh-autosuggestions
      zinit light Aloxaf/fzf-tab
      zinit snippet OMZP::git
      zinit snippet OMZP::sudo
      zinit snippet OMZP::command-not-found
      zinit snippet OMZP::brew
      zinit cdreplay -q

      # Gitstatus
      [[ -f "${pkgs.gitstatus}/gitstatus.plugin.zsh" ]] && source "${pkgs.gitstatus}/gitstatus.plugin.zsh"

      # Prompt setup
      source ${pkgs.geometry}/share/geometry/geometry.zsh
      GEOMETRY_STATUS_SYMBOL="󰅟 "
      GEOMETRY_STATUS_SYMBOL_ERROR="󰅣 "
      GEOMETRY_PATH_SHOW_BASENAME=true
      GEOMETRY_RPROMPT=(geometry_exec_time my_git_status geometry_echo)

      # Completion setup
      autoload -Uz compinit && compinit -C
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
      zstyle ":completion:*" list-colors "$LS_COLORS"
      zstyle ':completion:*' menu no

      # Shell integrations
      eval "$(fzf --zsh)"
      eval "$(zoxide init --cmd cd zsh)"

      # Set default editor
      export EDITOR="nvim"
    '';
  };
}
