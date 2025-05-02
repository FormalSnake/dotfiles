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
    initContent = ''
      alias cd='z'
      alias ls='ls -A --color'
      alias vim='nvim'
      alias add='git add'
      alias commit='git commit'
      alias push='git push'
      alias commitai='commit_message=$(lumen draft) && git commit -avm "$commit_message"'
      alias nah='git reset --hard && git clean -df'
      alias nixrb='clear && darwin-rebuild switch --flake .'
      alias nixrbgc='clear && darwin-rebuild switch --flake . && sudo nix-collect-garbage -d'
      alias wallpaper='matugen -c ~/.config/matugen/config.toml --verbose --contrast 0.2 image'
      alias brew-manager='~/.config/nix/./brew-manager.sh'

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
    # enableCompletion = true;
    # syntaxHighlighting.enable = true;
    # autosuggestion.enable = true;
    # history = {
    #   size = 5000;
    #   save = 5000;
    #   ignoreDups = true;
    #   ignoreAllDups = true;
    #   ignoreSpace = true;
    #   share = true;
    # };

    # initExtra = ''
    #   DISABLE_AUTO_UPDATE="true"
    #   skip_global_compinit=1
    #
    #   # Set up brew environment if on macOS
    #   if [[ -f "/opt/homebrew/bin/brew" ]]; then
    #     eval "$(/opt/homebrew/bin/brew shellenv)"
    #   fi
    #   # Shell integrations
    #   eval "$(fzf --zsh)"
    #   eval "$(zoxide init --cmd cd zsh)"
    #
    #   GEOMETRY_STATUS_SYMBOL="󰅟 "             # default prompt symbol
    #   GEOMETRY_STATUS_SYMBOL_ERROR="󰅣 "       # displayed when exit value is != 0
    #   GEOMETRY_PATH_SHOW_BASENAME=true
    #   GEOMETRY_RPROMPT=(geometry_exec_time geometry_git)
    #   source /opt/homebrew/opt/geometry/share/geometry/geometry.zsh
    #
    #   # Aliases
    #   alias ls='ls -A --color'
    #   alias vim='nvim'
    #   alias add='git add'
    #   alias commit='git commit'
    #   alias push='git push'
    #   alias commitai='commit_message=$(lumen draft) && git commit -avm "$commit_message"'
    #   alias nah='git reset --hard && git clean -df'
    #   alias nixrb='clear && darwin-rebuild switch --flake .'
    #   alias nixrbgc='clear && darwin-rebuild switch --flake . && sudo nix-collect-garbage -d'
    #   alias wallpaper='matugen -c ~/.config/matugen/config.toml --verbose --contrast 0.2 image'
    #
    #   # Functions
    #   function gpush() {
    #     git add .
    #     commit_message=$(lumen draft)
    #     if [ -z "$commit_message" ]; then
    #       echo "Lumen draft is empty"
    #       echo -n "Enter commit message: "
    #       read commit_message
    #     fi
    #     git commit -avm "$commit_message"
    #     git push origin main
    #   }
    # '';
    #
    # plugins = with pkgs; [
    #   {
    #     name = "fzf-tab";
    #     src = fetchFromGitHub {
    #       owner = "Aloxaf";
    #       repo = "fzf-tab";
    #       rev = "master";
    #       sha256 = "sha256-q26XVS/LcyZPRqDNwKKA9exgBByE0muyuNb0Bbar2lY=";
    #     };
    #   }
    #   {
    #     name = "zsh-syntax-highlighting";
    #     src = zsh-syntax-highlighting;
    #   }
    #   {
    #     name = "zsh-completions";
    #     src = zsh-completions;
    #   }
    #   {
    #     name = "zsh-autosuggestions";
    #     src = zsh-autosuggestions;
    #   }
    # ];
  };
}
