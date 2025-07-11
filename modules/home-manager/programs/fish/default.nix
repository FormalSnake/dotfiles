{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.fish = {
    enable = true;

    # Fish plugins via home-manager
    plugins = with pkgs.fishPlugins; [
      {
        name = "pure";
        src = pure.src;
      }
      {
        name = "autopair";
        src = autopair.src;
      }
      {
        name = "done";
        src = done.src;
      }
    ];

    # Shell aliases ported from zsh
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
      commitai = "set commit_message (lumen draft); and git commit -avm \"$commit_message\"";

      # System-specific aliases
      nixrb = lib.mkIf pkgs.stdenv.isDarwin "clear && nh darwin switch .";
      nixrbgc = lib.mkIf pkgs.stdenv.isDarwin "clear && nh darwin switch . && nh clean all";
      nixos-rb = lib.mkIf pkgs.stdenv.isLinux "clear && sudo nixos-rebuild switch --flake .";
      nixos-rbgc = lib.mkIf pkgs.stdenv.isLinux "clear && sudo nixos-rebuild switch --flake . && sudo nix-collect-garbage -d && sudo nix-store --verify --check-contents --repair";
    };

    # Fish shell initialization
    interactiveShellInit = ''
      # Set fish as default shell
      set -g fish_greeting ""

      # Set TERM for ghostty to fix ssh issues
      if test "$TERM_PROGRAM" = "ghostty"
          set -gx TERM xterm-256color
      end

      # Ensure nix paths are in PATH for fish
      fish_add_path /etc/profiles/per-user/kyandesutter/bin
      fish_add_path /run/current-system/sw/bin
      fish_add_path /nix/var/nix/profiles/default/bin
      fish_add_path ~/.nix-profile/bin

      # Add Python pip bin directory to PATH
      fish_add_path ~/Library/Python/3.9/bin

      # Shell integrations handled by home-manager fzf.nix and zoxide.nix

      # Functions ported from zsh
      function gpush
          git add .
          set commit_message (lumen draft)
          if test -z "$commit_message"
              echo "Lumen draft is empty"
              read -P "Enter commit message: " commit_message
          end
          git commit -avm "$commit_message"

          if test -n "$argv[1]"
              set branch_name $argv[1]
          else
              set branch_name "main"
          end
          git push origin $branch_name
      end

      function gcommit
          git add .
          set commit_message (lumen draft)
          if test -z "$commit_message"
              echo "Lumen draft is empty"
              read -P "Enter commit message: " commit_message
          end
          git commit -avm "$commit_message"
      end

      # Platform-specific initialization
      ${lib.optionalString pkgs.stdenv.isDarwin ''
        # Set up brew environment if on macOS
        if test -f "/opt/homebrew/bin/brew"
            eval (/opt/homebrew/bin/brew shellenv)
        end
      ''}

      # Load secret environment variables from ~/.config/fish/secrets.fish
      if test -f ~/.config/fish/secrets.fish
          source ~/.config/fish/secrets.fish
      end
    '';
  };

  # Create a template for secret environment variables
  home.file.".config/fish/secrets.fish.template" = {
    text = ''
      # This is a template for your secret environment variables
      # Copy this file to secrets.fish and add your actual secrets
      # secrets.fish is gitignored and won't be committed to your repository

      # Example usage:
      # set -gx OPENAI_API_KEY "your-openai-api-key-here"
      # set -gx ANTHROPIC_API_KEY "your-anthropic-api-key-here"
      # set -gx GITHUB_TOKEN "your-github-token-here"

      # Add your secret environment variables below:
    '';
  };

  # Ensure fish config directory exists
  home.file.".config/fish/.gitignore" = {
    text = ''
      secrets.fish
    '';
  };
}
