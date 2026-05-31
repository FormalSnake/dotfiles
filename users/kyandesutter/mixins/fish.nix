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

    functions = {
      gcommit = {
        description = "Git add and commit with AI message";
        body = ''
          git add .
          set commit_message (lumen draft)
          if test -z "$commit_message"
              echo "Lumen draft is empty"
              read -P "Enter commit message: " commit_message
          end
          git commit -avm "$commit_message"
        '';
      };

      gpush = {
        description = "Git add, commit with AI message, and push";
        body = ''
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
              set branch_name main
          end
          git push origin $branch_name
        '';
      };

      canaryclaude = {
        description = "Launch Claude Code routed through CanaryLLM";
        body = ''
          if not set -q CANARYLLM_API_KEY
              echo "CANARYLLM_API_KEY is not set (agenix secret missing?)" >&2
              return 1
          end
          ANTHROPIC_BASE_URL=https://canaryllm.canarycoders.es \
          ANTHROPIC_AUTH_TOKEN=$CANARYLLM_API_KEY \
          claude $argv
        '';
      };
    };

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

      # Nix itself (Determinate owns the install; nix-darwin's set-environment
      # adds this for zsh/bash but fish builds PATH by hand, so source the
      # official profile script — sets PATH, NIX_PROFILES, NIX_SSL_CERT_FILE).
      if test -f /nix/var/nix/profiles/default/etc/profile.d/nix.fish
          source /nix/var/nix/profiles/default/etc/profile.d/nix.fish
      end

      # Home-manager user profile (declared `home.packages`, e.g. `just`)
      fish_add_path /etc/profiles/per-user/kyandesutter/bin
      fish_add_path /run/current-system/sw/bin

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
    '';

    # Runs for ALL fish sessions (including non-interactive). Secrets and env
    # vars that scripts/subshells need belong here, not in interactiveShellInit.
    shellInit = ''
      # Agenix-decrypted secrets (mounted by nix-darwin at /run/agenix/<name>)
      function __load_agenix_secret -a env_name file
          if test -r "/run/agenix/$file"
              set -gx $env_name (cat "/run/agenix/$file")
          end
      end
      __load_agenix_secret OPENAI_API_KEY     openai
      __load_agenix_secret ANTHROPIC_API_KEY  anthropic
      __load_agenix_secret GEMINI_API_KEY     gemini
      __load_agenix_secret DEEPSEEK_API_KEY   deepseek
      __load_agenix_secret CANARYLLM_API_KEY  canaryllm
      __load_agenix_secret NUCLEO_LICENSE_KEY nucleo-license
      __load_agenix_secret NPM_GITHUB_TOKEN   npm-github-token
      __load_agenix_secret NPM_REGISTRY_TOKEN npm-registry-token

      # Lumen reuses the OpenAI key under a different name
      if set -q OPENAI_API_KEY
          set -gx LUMEN_AI_PROVIDER "openai"
          set -gx LUMEN_API_KEY $OPENAI_API_KEY
          set -gx LUMEN_AI_MODEL "gpt-5-mini"
      end

      # Non-secret AI provider settings (formerly in .zprofile)
      set -gx OLLAMA_API_BASE "https://ollama.kaiiserni.com"
      set -gx AIDER_WEAK_MODEL "gemini/gemini-2.0-flash"
    '';
  };
}
