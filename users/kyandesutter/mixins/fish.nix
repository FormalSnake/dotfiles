{ lib, pkgs, ... }:
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
      { name = "autopair"; src = pkgs.fishPlugins.autopair.src; }
      { name = "done"; src = pkgs.fishPlugins.done.src; }
    ];

    functions = {
      # PrismLinux's pure-fish prompt (prismlinux-themes-fish), plus a host
      # segment: three machines reached over ssh/mosh means the prompt has to
      # say which one you're on. Colours are ANSI names, not hex, so they ride
      # the terminal palette — matugen-derived on Linux, Flexoki on macOS.
      fish_prompt = {
        description = "Two-line prompt: user@host in path, then └─>>";
        body = ''
          set -l last_status $status
          set -l normal (set_color normal)

          set -l host (string lower (string replace -r '\..*$' "" -- $hostname))
          set -l host_color normal
          switch $host
              case 'macbook*'
                  set host macbook
                  set host_color magenta
              case g815
                  set host_color blue
              case e1504g
                  set host_color green
          end

          echo -n (set_color -o cyan)$USER$normal
          echo -n (set_color brblack)@$normal
          echo -n (set_color -o $host_color)$host$normal
          if set -q SSH_CONNECTION; or set -q SSH_TTY; or set -q SSH_CLIENT
              echo -n (set_color brblack)" ssh"$normal
          end

          set -l dir (string replace -r '^'(string escape --style=regex -- $HOME) '~' -- $PWD)
          set -l parts (string split / $dir)
          if test (count $parts) -gt 3
              set dir …/(string join / $parts[-3..-1])
          end
          echo -n " in "(set_color -o yellow)$dir$normal

          if not test -w $PWD
              echo -n (set_color red)" 🔒"$normal
          end

          # One `git status --porcelain=v2 --branch` feeds branch, dirty flags
          # and ahead/behind — a git call per field makes the prompt lag.
          set -l git_lines (command git status --porcelain=v2 --branch 2>/dev/null)
          and set -l branch (string replace -f '# branch.head ' "" -- $git_lines)
          if test -n "$branch"
              if test "$branch" = "(detached)"
                  set branch (string sub -l7 -- (string replace -f '# branch.oid ' "" -- $git_lines))
              end
              echo -n (set_color brblack)" on "$normal(set_color -o magenta)$branch$normal

              # porcelain v2 changed entries are `1|2 <XY> …`: X staged, Y unstaged.
              set -l xy (string replace -rf '^[12] (\S\S) .*' '$1' -- $git_lines)
              set -l flags
              string match -rq '^u ' -- $git_lines; and set flags $flags "="
              string match -rq '^[^.]' -- $xy; and set flags $flags "+"
              string match -rq '^.[^.]' -- $xy; and set flags $flags "!"
              string match -rq '^\? ' -- $git_lines; and set flags $flags "?"
              test (count $flags) -gt 0
              and echo -n (set_color -o red)" ["(string join "" $flags)"]"$normal

              set -l ab (string replace -f '# branch.ab ' "" -- $git_lines)
              if test -n "$ab"
                  set -l parts (string split " " -- $ab)
                  set -l ahead (string sub -s2 -- $parts[1])
                  set -l behind (string sub -s2 -- $parts[2])
                  test $ahead != 0; and echo -n (set_color cyan)" ⇡$ahead"$normal
                  test $behind != 0; and echo -n (set_color cyan)" ⇣$behind"$normal
              end
          end

          echo
          echo -n (set_color -o green)"└─>"$normal
          if test $last_status -eq 0
              echo -n (set_color -o green)">"$normal
          else
              echo -n (set_color -o red)">"$normal
          end
          echo -n " "
        '';
      };

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
              set branch_name (git rev-parse --abbrev-ref HEAD)
          end
          git push origin $branch_name
        '';
      };

      gpull = {
        description = "Git pull (rebase) from origin; launch Claude Code on merge conflicts";
        body = ''
          if test -n "$argv[1]"
              set branch_name $argv[1]
          else
              set branch_name (git rev-parse --abbrev-ref HEAD)
          end

          git pull --rebase origin $branch_name
          and return 0

          set conflicts (git diff --name-only --diff-filter=U)
          if test -z "$conflicts"
              return 1
          end

          echo "Merge conflicts detected — launching Claude Code…"
          set prompt (printf '%s\n' "Fix the following merge errors:" $conflicts | string collect)
          claude $prompt
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

      wgtunnel = {
        description = "WireGuard-over-wstunnel client (endpoint + path prefix from agenix)";
        body = ''
          if not set -q WSTUNNEL_ENDPOINT; or not set -q WSTUNNEL_PATH_PREFIX
              echo "WSTUNNEL_ENDPOINT / WSTUNNEL_PATH_PREFIX not set (agenix secret missing?)" >&2
              return 1
          end
          wstunnel client \
              -L 'udp://51820:localhost:51820?timeout_sec=0' \
              --http-upgrade-path-prefix $WSTUNNEL_PATH_PREFIX \
              $WSTUNNEL_ENDPOINT $argv
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

      ${lib.optionalString pkgs.stdenv.isDarwin ''
      # Brew environment
      if test -f /opt/homebrew/bin/brew
          /opt/homebrew/bin/brew shellenv | source
      end
      ''}
      # Nix itself (Determinate owns the install; nix-darwin's set-environment
      # adds this for zsh/bash but fish builds PATH by hand, so source the
      # official profile script — sets PATH, NIX_PROFILES, NIX_SSL_CERT_FILE).
      if test -f /nix/var/nix/profiles/default/etc/profile.d/nix.fish
          source /nix/var/nix/profiles/default/etc/profile.d/nix.fish
      end

      # Home-manager user profile (declared `home.packages`, e.g. `just`)
      fish_add_path /etc/profiles/per-user/kyandesutter/bin
      fish_add_path /run/current-system/sw/bin
      if test -d /run/wrappers/bin
        fish_add_path /run/wrappers/bin
      end

      # User paths
      fish_add_path ~/.cargo/bin
      fish_add_path ~/.bun/bin
      fish_add_path ~/.local/bin

      ${lib.optionalString pkgs.stdenv.isDarwin ''
      # OrbStack shell integration
      if test -f ~/.orbstack/shell/init2.fish
          source ~/.orbstack/shell/init2.fish
      end
      ''}
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
      __load_agenix_secret WSTUNNEL_PATH_PREFIX wstunnel-path-prefix
      __load_agenix_secret WSTUNNEL_ENDPOINT    wstunnel-endpoint

      # Lumen reuses the OpenAI key under a different name
      if set -q OPENAI_API_KEY
          set -gx LUMEN_AI_PROVIDER "openai"
          set -gx LUMEN_API_KEY $OPENAI_API_KEY
          set -gx LUMEN_AI_MODEL "gpt-5-mini"
      end

      # Non-secret AI provider settings (formerly in .zprofile)
      set -gx OLLAMA_API_BASE "https://ollama.kaiiserni.com"
      set -gx AIDER_WEAK_MODEL "gemini/gemini-2.0-flash"

      ${lib.optionalString pkgs.stdenv.isLinux ''
      # OpenSSH 10.1+ creates forwarded-agent sockets under ~/.ssh/agent/ and
      # unlinks them when their ssh session ends. Mosh's bootstrap ssh does
      # exactly that right after spawning mosh-server, so every shell inside a
      # mosh session (and anything launched from it — herdr, Claude) inherits a
      # dead SSH_AUTH_SOCK. When the socket is gone, fall back to the local gcr
      # agent: it holds this machine's on-disk key, which every host's sudo
      # mesh and authorized_keys accept. A live forwarded socket is kept as-is
      # (it carries the connecting host's richer keyring).
      if not test -S "$SSH_AUTH_SOCK"; and test -S "$XDG_RUNTIME_DIR/gcr/ssh"
          set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/gcr/ssh"
      end
      ''}
    '';
  };
}
