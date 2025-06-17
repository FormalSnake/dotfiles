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
      nixrb = lib.mkIf pkgs.stdenv.isDarwin "clear && sudo darwin-rebuild switch --flake .";
      nixrbgc = lib.mkIf pkgs.stdenv.isDarwin "clear && sudo darwin-rebuild switch --flake . && sudo nix-collect-garbage -d && sudo nix-store --verify --check-contents --repair";
      nixos-rb = lib.mkIf pkgs.stdenv.isLinux "clear && sudo nixos-rebuild switch --flake .";
      nixos-rbgc = lib.mkIf pkgs.stdenv.isLinux "clear && sudo nixos-rebuild switch --flake . && sudo nix-collect-garbage -d && sudo nix-store --verify --check-contents --repair";
    };

    # Fish shell initialization
    interactiveShellInit = ''
      # Set fish as default shell
      set -g fish_greeting ""
      
      # Ensure nix paths are in PATH for fish
      fish_add_path /etc/profiles/per-user/kyandesutter/bin
      fish_add_path /run/current-system/sw/bin
      fish_add_path /nix/var/nix/profiles/default/bin
      fish_add_path ~/.nix-profile/bin
      
      # Add Python pip bin directory to PATH
      fish_add_path ~/Library/Python/3.9/bin
      
      # Shell integrations handled by home-manager fzf.nix and zoxide.nix
      
      # System theme detection and responsive colors
      function __fish_is_dark_mode
          if test (uname) = "Darwin"
              # Check macOS system appearance
              test (defaults read -g AppleInterfaceStyle 2>/dev/null) = "Dark"
          else
              # For Linux, check common environment variables or fallback to dark
              if set -q DESKTOP_SESSION
                  string match -q "*dark*" $DESKTOP_SESSION
              else if set -q XDG_CURRENT_DESKTOP
                  # Check if dark theme is set in common desktop environments
                  switch $XDG_CURRENT_DESKTOP
                      case "GNOME"
                          test (gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | string match -r "dark|Dark") != ""
                      case "*"
                          true # Default to dark mode on Linux
                  end
              else
                  true # Default to dark mode
              end
          end
      end
      
      # Configure Pure prompt colors based on system theme
      if __fish_is_dark_mode
          # Dark mode colors - more vibrant
          set -g pure_color_blue (set_color blue)
          set -g pure_color_cyan (set_color cyan)
          set -g pure_color_gray (set_color 808080)
          set -g pure_color_green (set_color green)
          set -g pure_color_normal (set_color normal)
          set -g pure_color_red (set_color red)
          set -g pure_color_yellow (set_color yellow)
          set -g pure_color_white (set_color white)
          
          # Fish syntax highlighting for dark mode
          set -g fish_color_autosuggestion 555
          set -g fish_color_cancel -r
          set -g fish_color_command 5fd7ff
          set -g fish_color_comment 990000
          set -g fish_color_cwd green
          set -g fish_color_cwd_root red
          set -g fish_color_end 009900
          set -g fish_color_error ff0000
          set -g fish_color_escape 00a6b2
          set -g fish_color_history_current --bold
          set -g fish_color_host normal
          set -g fish_color_match --background=brblue
          set -g fish_color_normal normal
          set -g fish_color_operator 00a6b2
          set -g fish_color_param 5fd7ff
          set -g fish_color_quote 999900
          set -g fish_color_redirection 00afff
          set -g fish_color_search_match bryellow --background=brblack
          set -g fish_color_selection white --bold --background=brblack
          set -g fish_color_status red
          set -g fish_color_user brgreen
          set -g fish_color_valid_path --underline
      else
          # Light mode colors - muted and readable
          set -g pure_color_blue (set_color 0087d7)
          set -g pure_color_cyan (set_color 008787)
          set -g pure_color_gray (set_color 606060)
          set -g pure_color_green (set_color 008700)
          set -g pure_color_normal (set_color normal)
          set -g pure_color_red (set_color d70000)
          set -g pure_color_yellow (set_color af8700)
          set -g pure_color_white (set_color black)
          
          # Fish syntax highlighting for light mode
          set -g fish_color_autosuggestion 777
          set -g fish_color_cancel -r
          set -g fish_color_command 0087d7
          set -g fish_color_comment 8a8a8a
          set -g fish_color_cwd 008700
          set -g fish_color_cwd_root d70000
          set -g fish_color_end 008700
          set -g fish_color_error d70000
          set -g fish_color_escape 005f87
          set -g fish_color_history_current --bold
          set -g fish_color_host normal
          set -g fish_color_match --background=cyan
          set -g fish_color_normal normal
          set -g fish_color_operator 005f87
          set -g fish_color_param 0087d7
          set -g fish_color_quote af8700
          set -g fish_color_redirection 005faf
          set -g fish_color_search_match --background=yellow
          set -g fish_color_selection black --bold --background=white
          set -g fish_color_status d70000
          set -g fish_color_user 008700
          set -g fish_color_valid_path --underline
      end

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