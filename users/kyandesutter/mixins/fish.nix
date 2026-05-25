{ pkgs, ... }:
{
  programs.fish = {
    enable = true;

    shellAliases = {
      # Git shortcuts
      add = "git add";
      commit = "git commit";
      push = "git push";
      nah = "git reset --hard && git clean -df";
      commitai = ''set commit_message (lumen draft); and git commit -avm "$commit_message"'';

      # System utilities
      ls = "ls -A --color";
      vim = "nvim";
      cd = "z";

      # Modern CLI replacements
      cat = "bat";
      grep = "rg";
      find = "fd";
      top = "btop";

      # Tool shortcuts
      lg = "lazygit";
      ld = "lazydocker";
      y = "yazi";
    };

    # HM loads these natively — no fisher needed at the nix layer
    plugins = [
      { name = "pure"; src = pkgs.fishPlugins.pure.src; }
      { name = "autopair"; src = pkgs.fishPlugins.autopair.src; }
      { name = "done"; src = pkgs.fishPlugins.done.src; }
    ];

    interactiveShellInit = ''
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

      # User paths
      fish_add_path ~/.cargo/bin
      fish_add_path ~/.bun/bin
      fish_add_path ~/.local/bin
      fish_add_path ~/Library/Python/3.9/bin
      fish_add_path ~/Library/Android/sdk/emulator
      fish_add_path ~/Library/Android/sdk/platform-tools
      fish_add_path ~/.antigravity/antigravity/bin

      # OrbStack shell integration
      if test -f ~/.orbstack/shell/init2.fish
          source ~/.orbstack/shell/init2.fish
      end

      # Secrets — replaced by agenix in Phase 7
      if test -f ~/.config/fish/secrets.fish
          source ~/.config/fish/secrets.fish
      end
    '';
  };
}
