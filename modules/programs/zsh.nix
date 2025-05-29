{
  config,
  pkgs,
  lib,
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

    shellAliases = {
      # Navigation
      cd = "z";
      ls = "ls -A --color";

      # Editor
      vim = "nvim";

      # Git shortcuts
      add = "git add";
      commit = "git commit";
      push = "git push";
      nah = "git reset --hard && git clean -df";

      # AI-powered commits
      commitai = "commit_message=$(lumen draft) && git commit -avm \"$commit_message\"";

      # System-specific aliases
      nixrb = lib.mkIf pkgs.stdenv.isDarwin "clear && sudo darwin-rebuild switch --flake .";
      nixrbgc = lib.mkIf pkgs.stdenv.isDarwin "clear && sudo darwin-rebuild switch --flake . && sudo nix-collect-garbage -d && sudo nix-store --verify --check-contents --repair";
      nixos-rb = lib.mkIf pkgs.stdenv.isLinux "clear && sudo nixos-rebuild switch --flake .";
      nixos-rbgc = lib.mkIf pkgs.stdenv.isLinux "clear && sudo nixos-rebuild switch --flake . && sudo nix-collect-garbage -d && sudo nix-store --verify --check-contents --repair";
    };

    initContent = ''
      # Shell integrations
      eval "$(fzf --zsh)"
      eval "$(zoxide init --cmd cd zsh)"

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

        if [ -n "$1" ]; then
          branch_name="$1"
        else
          branch_name="main"
        fi
        git push origin "$branch_name"
      }

      # Platform-specific initialization
      ${lib.optionalString pkgs.stdenv.isDarwin ''
        # Set up brew environment if on macOS
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
      ''}
    '';
  };
}
